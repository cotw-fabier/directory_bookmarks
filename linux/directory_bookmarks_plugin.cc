#include "include/directory_bookmarks/directory_bookmarks_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#include <cstring>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <unistd.h>
#include <sys/stat.h>
#include "json.hpp"

namespace fs = std::filesystem;
using json = nlohmann::json;

#define DIRECTORY_BOOKMARKS_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), directory_bookmarks_plugin_get_type(), \
                               DirectoryBookmarksPlugin))

struct _DirectoryBookmarksPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(DirectoryBookmarksPlugin, directory_bookmarks_plugin, g_object_get_type())

// Helper function to get the bookmarks config file path
static std::string get_bookmarks_config_path() {
  const char* config_home = g_get_user_config_dir();
  std::string config_dir = std::string(config_home) + "/directory_bookmarks";

  // Create config directory if it doesn't exist
  fs::create_directories(config_dir);

  return config_dir + "/bookmarks.json";
}

// Helper function to create FlValue from string
static FlValue* fl_value_new_string_safe(const std::string& str) {
  return fl_value_new_string(str.c_str());
}

// Helper function to get current timestamp in ISO8601 format
static std::string get_iso8601_timestamp() {
  time_t now = time(nullptr);
  char timestamp[32];
  strftime(timestamp, sizeof(timestamp), "%Y-%m-%dT%H:%M:%SZ", gmtime(&now));
  return std::string(timestamp);
}

// Helper function to convert FlValue map to json
static json fl_value_to_json(FlValue* value) {
  if (value == nullptr || fl_value_get_type(value) == FL_VALUE_TYPE_NULL) {
    return json::object();
  }

  if (fl_value_get_type(value) != FL_VALUE_TYPE_MAP) {
    return json::object();
  }

  json result = json::object();
  size_t length = fl_value_get_length(value);

  for (size_t i = 0; i < length; i++) {
    FlValue* key_value = fl_value_get_map_key(value, i);
    FlValue* val = fl_value_get_map_value(value, i);

    if (fl_value_get_type(key_value) == FL_VALUE_TYPE_STRING) {
      const char* key = fl_value_get_string(key_value);

      switch (fl_value_get_type(val)) {
        case FL_VALUE_TYPE_STRING:
          result[key] = fl_value_get_string(val);
          break;
        case FL_VALUE_TYPE_INT:
          result[key] = fl_value_get_int(val);
          break;
        case FL_VALUE_TYPE_FLOAT:
          result[key] = fl_value_get_float(val);
          break;
        case FL_VALUE_TYPE_BOOL:
          result[key] = fl_value_get_bool(val);
          break;
        default:
          result[key] = nullptr;
          break;
      }
    }
  }

  return result;
}

// Helper function to convert json to FlValue map
static FlValue* json_to_fl_value(const json& j) {
  if (j.is_null() || !j.is_object()) {
    return fl_value_new_map();
  }

  g_autoptr(FlValue) result = fl_value_new_map();

  for (auto& [key, value] : j.items()) {
    if (value.is_string()) {
      fl_value_set_string_take(result, key.c_str(),
                               fl_value_new_string(value.get<std::string>().c_str()));
    } else if (value.is_number_integer()) {
      fl_value_set_string_take(result, key.c_str(),
                               fl_value_new_int(value.get<int64_t>()));
    } else if (value.is_number_float()) {
      fl_value_set_string_take(result, key.c_str(),
                               fl_value_new_float(value.get<double>()));
    } else if (value.is_boolean()) {
      fl_value_set_string_take(result, key.c_str(),
                               fl_value_new_bool(value.get<bool>()));
    }
  }

  return fl_value_ref(result);
}

// Load all bookmarks from storage
static json load_bookmarks() {
  std::string config_path = get_bookmarks_config_path();

  // If file doesn't exist, return empty structure
  if (!fs::exists(config_path)) {
    return json{
      {"version", "2.0"},
      {"bookmarks", json::object()}
    };
  }

  try {
    std::ifstream in(config_path);
    if (!in.is_open()) {
      return json{
        {"version", "2.0"},
        {"bookmarks", json::object()}
      };
    }

    json data = json::parse(in);
    in.close();

    // Validate structure
    if (!data.contains("bookmarks") || !data["bookmarks"].is_object()) {
      return json{
        {"version", "2.0"},
        {"bookmarks", json::object()}
      };
    }

    return data;
  } catch (const std::exception& e) {
    // Parse error - return empty structure
    return json{
      {"version", "2.0"},
      {"bookmarks", json::object()}
    };
  }
}

// Save all bookmarks to storage (atomic write)
static bool save_bookmarks(const json& data) {
  std::string config_path = get_bookmarks_config_path();
  std::string temp_path = config_path + ".tmp";

  try {
    std::ofstream out(temp_path);
    if (!out.is_open()) {
      return false;
    }

    out << data.dump(2);  // Pretty print with 2-space indent
    out.close();

    // Atomic rename
    fs::rename(temp_path, config_path);
    return true;
  } catch (const std::exception& e) {
    // Clean up temp file if it exists
    if (fs::exists(temp_path)) {
      fs::remove(temp_path);
    }
    return false;
  }
}

// Method: createBookmark
static FlMethodResponse* create_bookmark(FlValue* args) {
  FlValue* identifier_value = fl_value_lookup_string(args, "identifier");
  FlValue* path_value = fl_value_lookup_string(args, "path");

  if (identifier_value == nullptr || fl_value_get_type(identifier_value) != FL_VALUE_TYPE_STRING) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "INVALID_ARGUMENT", "identifier must be a string", nullptr));
  }

  if (path_value == nullptr || fl_value_get_type(path_value) != FL_VALUE_TYPE_STRING) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "INVALID_ARGUMENT", "path must be a string", nullptr));
  }

  const char* identifier = fl_value_get_string(identifier_value);
  const char* path = fl_value_get_string(path_value);

  // Validate directory exists and is accessible
  struct stat st;
  if (stat(path, &st) != 0 || !S_ISDIR(st.st_mode)) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "DIRECTORY_NOT_FOUND", "Directory not found or is not accessible", nullptr));
  }

  // Load existing bookmarks
  json data = load_bookmarks();

  // Check if bookmark already exists
  if (data["bookmarks"].contains(identifier)) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "BOOKMARK_ALREADY_EXISTS",
        ("Bookmark with identifier '" + std::string(identifier) + "' already exists").c_str(),
        nullptr));
  }

  // Create bookmark entry
  json bookmark = {
    {"id", identifier},
    {"path", path},
    {"createdAt", get_iso8601_timestamp()},
    {"metadata", json::object()}
  };

  // Handle custom metadata if provided
  FlValue* metadata_value = fl_value_lookup_string(args, "metadata");
  if (metadata_value != nullptr && fl_value_get_type(metadata_value) == FL_VALUE_TYPE_MAP) {
    bookmark["metadata"] = fl_value_to_json(metadata_value);
  }

  // Add to bookmarks
  data["bookmarks"][identifier] = bookmark;

  // Save to storage
  if (!save_bookmarks(data)) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "WRITE_ERROR", "Failed to save bookmark", nullptr));
  }

  return FL_METHOD_RESPONSE(fl_method_success_response_new(
      fl_value_new_string(identifier)));
}

// Method: listBookmarks
static FlMethodResponse* list_bookmarks() {
  json data = load_bookmarks();
  g_autoptr(FlValue) result = fl_value_new_list();

  for (auto& [id, bookmark] : data["bookmarks"].items()) {
    g_autoptr(FlValue) bookmark_map = fl_value_new_map();

    fl_value_set_string_take(bookmark_map, "identifier",
                             fl_value_new_string(bookmark["id"].get<std::string>().c_str()));
    fl_value_set_string_take(bookmark_map, "path",
                             fl_value_new_string(bookmark["path"].get<std::string>().c_str()));
    fl_value_set_string_take(bookmark_map, "createdAt",
                             fl_value_new_string(bookmark["createdAt"].get<std::string>().c_str()));

    if (bookmark.contains("metadata") && bookmark["metadata"].is_object()) {
      fl_value_set_string_take(bookmark_map, "metadata",
                               json_to_fl_value(bookmark["metadata"]));
    } else {
      fl_value_set_string_take(bookmark_map, "metadata", fl_value_new_map());
    }

    fl_value_append_take(result, fl_value_ref(bookmark_map));
  }

  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

// Method: getBookmark
static FlMethodResponse* get_bookmark(FlValue* args) {
  FlValue* identifier_value = fl_value_lookup_string(args, "identifier");

  if (identifier_value == nullptr || fl_value_get_type(identifier_value) != FL_VALUE_TYPE_STRING) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "INVALID_ARGUMENT", "identifier must be a string", nullptr));
  }

  const char* identifier = fl_value_get_string(identifier_value);
  json data = load_bookmarks();

  // Check if bookmark exists
  if (!data["bookmarks"].contains(identifier)) {
    return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_null()));
  }

  json bookmark = data["bookmarks"][identifier];

  g_autoptr(FlValue) result = fl_value_new_map();
  fl_value_set_string_take(result, "identifier",
                           fl_value_new_string(bookmark["id"].get<std::string>().c_str()));
  fl_value_set_string_take(result, "path",
                           fl_value_new_string(bookmark["path"].get<std::string>().c_str()));
  fl_value_set_string_take(result, "createdAt",
                           fl_value_new_string(bookmark["createdAt"].get<std::string>().c_str()));

  if (bookmark.contains("metadata") && bookmark["metadata"].is_object()) {
    fl_value_set_string_take(result, "metadata",
                             json_to_fl_value(bookmark["metadata"]));
  } else {
    fl_value_set_string_take(result, "metadata", fl_value_new_map());
  }

  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

// Method: bookmarkExists
static FlMethodResponse* bookmark_exists(FlValue* args) {
  FlValue* identifier_value = fl_value_lookup_string(args, "identifier");

  if (identifier_value == nullptr || fl_value_get_type(identifier_value) != FL_VALUE_TYPE_STRING) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "INVALID_ARGUMENT", "identifier must be a string", nullptr));
  }

  const char* identifier = fl_value_get_string(identifier_value);
  json data = load_bookmarks();

  bool exists = data["bookmarks"].contains(identifier);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(exists)));
}

// Method: deleteBookmark
static FlMethodResponse* delete_bookmark(FlValue* args) {
  FlValue* identifier_value = fl_value_lookup_string(args, "identifier");

  if (identifier_value == nullptr || fl_value_get_type(identifier_value) != FL_VALUE_TYPE_STRING) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "INVALID_ARGUMENT", "identifier must be a string", nullptr));
  }

  const char* identifier = fl_value_get_string(identifier_value);
  json data = load_bookmarks();

  // Check if bookmark exists
  if (!data["bookmarks"].contains(identifier)) {
    return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(false)));
  }

  // Remove bookmark
  data["bookmarks"].erase(identifier);

  // Save to storage
  if (!save_bookmarks(data)) {
    return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(false)));
  }

  return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(true)));
}

// Method: updateBookmarkMetadata
static FlMethodResponse* update_bookmark_metadata(FlValue* args) {
  FlValue* identifier_value = fl_value_lookup_string(args, "identifier");
  FlValue* metadata_value = fl_value_lookup_string(args, "metadata");

  if (identifier_value == nullptr || fl_value_get_type(identifier_value) != FL_VALUE_TYPE_STRING) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "INVALID_ARGUMENT", "identifier must be a string", nullptr));
  }

  if (metadata_value == nullptr || fl_value_get_type(metadata_value) != FL_VALUE_TYPE_MAP) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "INVALID_ARGUMENT", "metadata must be a map", nullptr));
  }

  const char* identifier = fl_value_get_string(identifier_value);
  json data = load_bookmarks();

  // Check if bookmark exists
  if (!data["bookmarks"].contains(identifier)) {
    return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(false)));
  }

  // Update metadata
  data["bookmarks"][identifier]["metadata"] = fl_value_to_json(metadata_value);

  // Save to storage
  if (!save_bookmarks(data)) {
    return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(false)));
  }

  return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(true)));
}

// Helper: Get bookmarked directory path by identifier
static bool get_bookmarked_path(const char* identifier, std::string& out_path) {
  json data = load_bookmarks();

  if (!data["bookmarks"].contains(identifier)) {
    return false;
  }

  json bookmark = data["bookmarks"][identifier];
  out_path = bookmark["path"].get<std::string>();

  // Validate directory still exists
  struct stat st;
  if (stat(out_path.c_str(), &st) != 0 || !S_ISDIR(st.st_mode)) {
    return false;
  }

  return true;
}

// Method: saveFile
static FlMethodResponse* save_file(FlValue* args) {
  FlValue* identifier_value = fl_value_lookup_string(args, "identifier");
  FlValue* filename_value = fl_value_lookup_string(args, "fileName");
  FlValue* data_value = fl_value_lookup_string(args, "data");

  if (identifier_value == nullptr || fl_value_get_type(identifier_value) != FL_VALUE_TYPE_STRING) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "INVALID_ARGUMENT", "identifier must be a string", nullptr));
  }

  if (filename_value == nullptr || fl_value_get_type(filename_value) != FL_VALUE_TYPE_STRING) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "INVALID_ARGUMENT", "fileName must be a string", nullptr));
  }

  if (data_value == nullptr || fl_value_get_type(data_value) != FL_VALUE_TYPE_UINT8_LIST) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "INVALID_ARGUMENT", "data must be a Uint8List", nullptr));
  }

  const char* identifier = fl_value_get_string(identifier_value);
  const char* filename = fl_value_get_string(filename_value);

  // Get bookmarked directory
  std::string bookmark_path;
  if (!get_bookmarked_path(identifier, bookmark_path)) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "BOOKMARK_NOT_FOUND",
        ("Bookmark with identifier '" + std::string(identifier) + "' not found").c_str(),
        nullptr));
  }

  // Check write permission
  if (access(bookmark_path.c_str(), W_OK) != 0) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "PERMISSION_DENIED", "No write permission for bookmarked directory", nullptr));
  }

  // Build full file path
  std::string file_path = bookmark_path + "/" + filename;

  // Write file
  try {
    std::ofstream out(file_path, std::ios::binary);
    if (!out.is_open()) {
      return FL_METHOD_RESPONSE(fl_method_error_response_new(
          "PERMISSION_DENIED", "Cannot write file", nullptr));
    }

    const uint8_t* data = fl_value_get_uint8_list(data_value);
    size_t data_length = fl_value_get_length(data_value);
    out.write(reinterpret_cast<const char*>(data), data_length);
    out.close();

    return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(true)));
  } catch (const std::exception& e) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "WRITE_ERROR", e.what(), nullptr));
  }
}

// Method: readFile
static FlMethodResponse* read_file(FlValue* args) {
  FlValue* identifier_value = fl_value_lookup_string(args, "identifier");
  FlValue* filename_value = fl_value_lookup_string(args, "fileName");

  if (identifier_value == nullptr || fl_value_get_type(identifier_value) != FL_VALUE_TYPE_STRING) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "INVALID_ARGUMENT", "identifier must be a string", nullptr));
  }

  if (filename_value == nullptr || fl_value_get_type(filename_value) != FL_VALUE_TYPE_STRING) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "INVALID_ARGUMENT", "fileName must be a string", nullptr));
  }

  const char* identifier = fl_value_get_string(identifier_value);
  const char* filename = fl_value_get_string(filename_value);

  // Get bookmarked directory
  std::string bookmark_path;
  if (!get_bookmarked_path(identifier, bookmark_path)) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "BOOKMARK_NOT_FOUND",
        ("Bookmark with identifier '" + std::string(identifier) + "' not found").c_str(),
        nullptr));
  }

  // Build full file path
  std::string file_path = bookmark_path + "/" + filename;

  // Check if file exists
  if (!fs::exists(file_path) || !fs::is_regular_file(file_path)) {
    return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_null()));
  }

  // Read file
  try {
    std::ifstream in(file_path, std::ios::binary | std::ios::ate);
    if (!in.is_open()) {
      return FL_METHOD_RESPONSE(fl_method_error_response_new(
          "PERMISSION_DENIED", "Cannot read file", nullptr));
    }

    std::streamsize size = in.tellg();
    in.seekg(0, std::ios::beg);

    std::vector<uint8_t> buffer(size);
    in.read(reinterpret_cast<char*>(buffer.data()), size);
    in.close();

    g_autoptr(FlValue) result = fl_value_new_uint8_list(buffer.data(), buffer.size());
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } catch (const std::exception& e) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "READ_ERROR", e.what(), nullptr));
  }
}

// Method: listFiles
static FlMethodResponse* list_files(FlValue* args) {
  FlValue* identifier_value = fl_value_lookup_string(args, "identifier");

  if (identifier_value == nullptr || fl_value_get_type(identifier_value) != FL_VALUE_TYPE_STRING) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "INVALID_ARGUMENT", "identifier must be a string", nullptr));
  }

  const char* identifier = fl_value_get_string(identifier_value);

  // Get bookmarked directory
  std::string bookmark_path;
  if (!get_bookmarked_path(identifier, bookmark_path)) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "BOOKMARK_NOT_FOUND",
        ("Bookmark with identifier '" + std::string(identifier) + "' not found").c_str(),
        nullptr));
  }

  // List files
  try {
    g_autoptr(FlValue) result = fl_value_new_list();

    for (const auto& entry : fs::directory_iterator(bookmark_path)) {
      if (entry.is_regular_file()) {
        std::string filename = entry.path().filename().string();
        // Filter hidden files (starting with .)
        if (!filename.empty() && filename[0] != '.') {
          fl_value_append_take(result, fl_value_new_string_safe(filename));
        }
      }
    }

    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } catch (const std::exception& e) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "READ_ERROR", e.what(), nullptr));
  }
}

// Method: deleteFile
static FlMethodResponse* delete_file(FlValue* args) {
  FlValue* identifier_value = fl_value_lookup_string(args, "identifier");
  FlValue* filename_value = fl_value_lookup_string(args, "fileName");

  if (identifier_value == nullptr || fl_value_get_type(identifier_value) != FL_VALUE_TYPE_STRING) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "INVALID_ARGUMENT", "identifier must be a string", nullptr));
  }

  if (filename_value == nullptr || fl_value_get_type(filename_value) != FL_VALUE_TYPE_STRING) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "INVALID_ARGUMENT", "fileName must be a string", nullptr));
  }

  const char* identifier = fl_value_get_string(identifier_value);
  const char* filename = fl_value_get_string(filename_value);

  // Get bookmarked directory
  std::string bookmark_path;
  if (!get_bookmarked_path(identifier, bookmark_path)) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "BOOKMARK_NOT_FOUND",
        ("Bookmark with identifier '" + std::string(identifier) + "' not found").c_str(),
        nullptr));
  }

  // Check write permission
  if (access(bookmark_path.c_str(), W_OK) != 0) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "PERMISSION_DENIED", "No write permission for bookmarked directory", nullptr));
  }

  // Build full file path
  std::string file_path = bookmark_path + "/" + filename;

  // Check if file exists
  if (!fs::exists(file_path) || !fs::is_regular_file(file_path)) {
    return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(false)));
  }

  // Delete file
  try {
    fs::remove(file_path);
    return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(true)));
  } catch (const std::exception& e) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "DELETE_ERROR", e.what(), nullptr));
  }
}

// Method: fileExists
static FlMethodResponse* file_exists(FlValue* args) {
  FlValue* identifier_value = fl_value_lookup_string(args, "identifier");
  FlValue* filename_value = fl_value_lookup_string(args, "fileName");

  if (identifier_value == nullptr || fl_value_get_type(identifier_value) != FL_VALUE_TYPE_STRING) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "INVALID_ARGUMENT", "identifier must be a string", nullptr));
  }

  if (filename_value == nullptr || fl_value_get_type(filename_value) != FL_VALUE_TYPE_STRING) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "INVALID_ARGUMENT", "fileName must be a string", nullptr));
  }

  const char* identifier = fl_value_get_string(identifier_value);
  const char* filename = fl_value_get_string(filename_value);

  // Get bookmarked directory
  std::string bookmark_path;
  if (!get_bookmarked_path(identifier, bookmark_path)) {
    return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(false)));
  }

  // Build full file path
  std::string file_path = bookmark_path + "/" + filename;

  // Check if file exists
  bool exists = fs::exists(file_path) && fs::is_regular_file(file_path);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(exists)));
}

// Method: hasWritePermission
static FlMethodResponse* has_write_permission(FlValue* args) {
  FlValue* identifier_value = fl_value_lookup_string(args, "identifier");

  if (identifier_value == nullptr || fl_value_get_type(identifier_value) != FL_VALUE_TYPE_STRING) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "INVALID_ARGUMENT", "identifier must be a string", nullptr));
  }

  const char* identifier = fl_value_get_string(identifier_value);

  std::string bookmark_path;
  if (!get_bookmarked_path(identifier, bookmark_path)) {
    return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(false)));
  }

  bool has_permission = (access(bookmark_path.c_str(), W_OK) == 0);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(has_permission)));
}

// Method: requestWritePermission
static FlMethodResponse* request_write_permission(FlValue* args) {
  // On Linux desktop, we don't need runtime permission dialogs
  // Just return the current write permission status
  return has_write_permission(args);
}

// MethodChannel handler
static void directory_bookmarks_plugin_handle_method_call(
    DirectoryBookmarksPlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  if (strcmp(method, "createBookmark") == 0) {
    response = create_bookmark(args);
  } else if (strcmp(method, "listBookmarks") == 0) {
    response = list_bookmarks();
  } else if (strcmp(method, "getBookmark") == 0) {
    response = get_bookmark(args);
  } else if (strcmp(method, "bookmarkExists") == 0) {
    response = bookmark_exists(args);
  } else if (strcmp(method, "deleteBookmark") == 0) {
    response = delete_bookmark(args);
  } else if (strcmp(method, "updateBookmarkMetadata") == 0) {
    response = update_bookmark_metadata(args);
  } else if (strcmp(method, "saveFile") == 0) {
    response = save_file(args);
  } else if (strcmp(method, "readFile") == 0) {
    response = read_file(args);
  } else if (strcmp(method, "listFiles") == 0) {
    response = list_files(args);
  } else if (strcmp(method, "deleteFile") == 0) {
    response = delete_file(args);
  } else if (strcmp(method, "fileExists") == 0) {
    response = file_exists(args);
  } else if (strcmp(method, "hasWritePermission") == 0) {
    response = has_write_permission(args);
  } else if (strcmp(method, "requestWritePermission") == 0) {
    response = request_write_permission(args);
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void directory_bookmarks_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(directory_bookmarks_plugin_parent_class)->dispose(object);
}

static void directory_bookmarks_plugin_class_init(DirectoryBookmarksPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = directory_bookmarks_plugin_dispose;
}

static void directory_bookmarks_plugin_init(DirectoryBookmarksPlugin* self) {}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                          gpointer user_data) {
  DirectoryBookmarksPlugin* plugin = DIRECTORY_BOOKMARKS_PLUGIN(user_data);
  directory_bookmarks_plugin_handle_method_call(plugin, method_call);
}

void directory_bookmarks_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  DirectoryBookmarksPlugin* plugin = DIRECTORY_BOOKMARKS_PLUGIN(
      g_object_new(directory_bookmarks_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                           "com.example.directory_bookmarks/bookmark",
                           FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                           g_object_ref(plugin),
                                           g_object_unref);

  g_object_unref(plugin);
}
