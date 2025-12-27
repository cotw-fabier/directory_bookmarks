#include "include/directory_bookmarks/directory_bookmarks_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#include <cstring>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <unistd.h>
#include <sys/stat.h>

namespace fs = std::filesystem;

#define DIRECTORY_BOOKMARKS_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), directory_bookmarks_plugin_get_type(), \
                               DirectoryBookmarksPlugin))

struct _DirectoryBookmarksPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(DirectoryBookmarksPlugin, directory_bookmarks_plugin, g_object_get_type())

// Helper function to get the bookmark config file path
static std::string get_bookmark_config_path() {
  const char* config_home = g_get_user_config_dir();
  std::string config_dir = std::string(config_home) + "/directory_bookmarks";

  // Create config directory if it doesn't exist
  fs::create_directories(config_dir);

  return config_dir + "/bookmark.json";
}

// Helper function to create FlValue from string
static FlValue* fl_value_new_string_safe(const std::string& str) {
  return fl_value_new_string(str.c_str());
}

// Helper function to escape JSON strings
static std::string json_escape(const std::string& str) {
  std::string result;
  for (char c : str) {
    switch (c) {
      case '"': result += "\\\""; break;
      case '\\': result += "\\\\"; break;
      case '\b': result += "\\b"; break;
      case '\f': result += "\\f"; break;
      case '\n': result += "\\n"; break;
      case '\r': result += "\\r"; break;
      case '\t': result += "\\t"; break;
      default:
        if (c < 0x20) {
          char buf[7];
          snprintf(buf, sizeof(buf), "\\u%04x", c);
          result += buf;
        } else {
          result += c;
        }
    }
  }
  return result;
}

// Simple JSON parser for reading bookmark data
static bool parse_bookmark_json(const std::string& json, std::string& path,
                                std::string& created_at, FlValue*& metadata) {
  // Very simple JSON parser - just extract the fields we need
  size_t path_pos = json.find("\"path\":");
  size_t created_at_pos = json.find("\"createdAt\":");
  size_t metadata_pos = json.find("\"metadata\":");

  if (path_pos == std::string::npos || created_at_pos == std::string::npos) {
    return false;
  }

  // Extract path
  size_t path_start = json.find("\"", path_pos + 7);
  size_t path_end = json.find("\"", path_start + 1);
  if (path_start == std::string::npos || path_end == std::string::npos) {
    return false;
  }
  path = json.substr(path_start + 1, path_end - path_start - 1);

  // Extract createdAt
  size_t created_start = json.find("\"", created_at_pos + 12);
  size_t created_end = json.find("\"", created_start + 1);
  if (created_start == std::string::npos || created_end == std::string::npos) {
    return false;
  }
  created_at = json.substr(created_start + 1, created_end - created_start - 1);

  // Extract metadata (if present)
  if (metadata_pos != std::string::npos) {
    size_t meta_start = json.find("{", metadata_pos + 11);
    size_t meta_end = json.find("}", meta_start);
    if (meta_start != std::string::npos && meta_end != std::string::npos) {
      // For simplicity, return empty map for now
      // Full JSON parsing would require a library
      metadata = fl_value_new_map();
    } else {
      metadata = fl_value_new_null();
    }
  } else {
    metadata = fl_value_new_null();
  }

  return true;
}

// Method: saveDirectoryBookmark
static FlMethodResponse* save_directory_bookmark(FlValue* args) {
  FlValue* path_value = fl_value_lookup_string(args, "path");
  if (path_value == nullptr || fl_value_get_type(path_value) != FL_VALUE_TYPE_STRING) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "INVALID_ARGUMENT", "Path must be a string", nullptr));
  }

  const char* path = fl_value_get_string(path_value);

  // Validate directory exists and is accessible
  struct stat st;
  if (stat(path, &st) != 0 || !S_ISDIR(st.st_mode)) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "DIRECTORY_NOT_FOUND", "Directory not found or is not accessible", nullptr));
  }

  // Get current timestamp in ISO8601 format
  time_t now = time(nullptr);
  char timestamp[32];
  strftime(timestamp, sizeof(timestamp), "%Y-%m-%dT%H:%M:%SZ", gmtime(&now));

  // Build JSON (simple approach without external library)
  std::ostringstream json;
  json << "{\n";
  json << "  \"path\": \"" << json_escape(path) << "\",\n";
  json << "  \"createdAt\": \"" << timestamp << "\",\n";

  // Handle metadata if provided
  FlValue* metadata_value = fl_value_lookup_string(args, "metadata");
  if (metadata_value != nullptr && fl_value_get_type(metadata_value) == FL_VALUE_TYPE_MAP) {
    json << "  \"metadata\": {}\n";  // Simplified - would need full map serialization
  } else {
    json << "  \"metadata\": null\n";
  }
  json << "}\n";

  // Write to config file atomically (write to temp, then rename)
  std::string config_path = get_bookmark_config_path();
  std::string temp_path = config_path + ".tmp";

  try {
    std::ofstream out(temp_path);
    if (!out.is_open()) {
      return FL_METHOD_RESPONSE(fl_method_error_response_new(
          "PERMISSION_DENIED", "Cannot write to config directory", nullptr));
    }
    out << json.str();
    out.close();

    // Atomic rename
    fs::rename(temp_path, config_path);

    return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(true)));
  } catch (const std::exception& e) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "WRITE_ERROR", e.what(), nullptr));
  }
}

// Method: resolveDirectoryBookmark
static FlMethodResponse* resolve_directory_bookmark() {
  std::string config_path = get_bookmark_config_path();

  // Check if bookmark file exists
  if (!fs::exists(config_path)) {
    return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_null()));
  }

  // Read bookmark file
  std::ifstream in(config_path);
  if (!in.is_open()) {
    return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_null()));
  }

  std::string json((std::istreambuf_iterator<char>(in)),
                   std::istreambuf_iterator<char>());
  in.close();

  // Parse JSON
  std::string path, created_at;
  FlValue* metadata;
  if (!parse_bookmark_json(json, path, created_at, metadata)) {
    return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_null()));
  }

  // Validate directory still exists
  struct stat st;
  if (stat(path.c_str(), &st) != 0 || !S_ISDIR(st.st_mode)) {
    return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_null()));
  }

  // Build result map
  g_autoptr(FlValue) result = fl_value_new_map();
  fl_value_set_string_take(result, "path", fl_value_new_string_safe(path));
  fl_value_set_string_take(result, "createdAt", fl_value_new_string_safe(created_at));
  fl_value_set_string_take(result, "metadata", metadata);

  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

// Helper: Get bookmarked directory path
static bool get_bookmarked_path(std::string& out_path) {
  std::string config_path = get_bookmark_config_path();

  if (!fs::exists(config_path)) {
    return false;
  }

  std::ifstream in(config_path);
  if (!in.is_open()) {
    return false;
  }

  std::string json((std::istreambuf_iterator<char>(in)),
                   std::istreambuf_iterator<char>());
  in.close();

  std::string created_at;
  FlValue* metadata;
  if (!parse_bookmark_json(json, out_path, created_at, metadata)) {
    return false;
  }

  // Validate directory still exists
  struct stat st;
  if (stat(out_path.c_str(), &st) != 0 || !S_ISDIR(st.st_mode)) {
    return false;
  }

  return true;
}

// Method: saveFile
static FlMethodResponse* save_file(FlValue* args) {
  FlValue* filename_value = fl_value_lookup_string(args, "fileName");
  FlValue* data_value = fl_value_lookup_string(args, "data");

  if (filename_value == nullptr || fl_value_get_type(filename_value) != FL_VALUE_TYPE_STRING) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "INVALID_ARGUMENT", "fileName must be a string", nullptr));
  }

  if (data_value == nullptr || fl_value_get_type(data_value) != FL_VALUE_TYPE_UINT8_LIST) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "INVALID_ARGUMENT", "data must be a Uint8List", nullptr));
  }

  const char* filename = fl_value_get_string(filename_value);

  // Get bookmarked directory
  std::string bookmark_path;
  if (!get_bookmarked_path(bookmark_path)) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "DIRECTORY_NOT_FOUND", "No valid bookmark found", nullptr));
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
  FlValue* filename_value = fl_value_lookup_string(args, "fileName");

  if (filename_value == nullptr || fl_value_get_type(filename_value) != FL_VALUE_TYPE_STRING) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "INVALID_ARGUMENT", "fileName must be a string", nullptr));
  }

  const char* filename = fl_value_get_string(filename_value);

  // Get bookmarked directory
  std::string bookmark_path;
  if (!get_bookmarked_path(bookmark_path)) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "DIRECTORY_NOT_FOUND", "No valid bookmark found", nullptr));
  }

  // Build full file path
  std::string file_path = bookmark_path + "/" + filename;

  // Check if file exists
  if (!fs::exists(file_path) || !fs::is_regular_file(file_path)) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "FILE_NOT_FOUND", "File not found", nullptr));
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
static FlMethodResponse* list_files() {
  // Get bookmarked directory
  std::string bookmark_path;
  if (!get_bookmarked_path(bookmark_path)) {
    return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_null()));
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

// Method: hasWritePermission
static FlMethodResponse* has_write_permission() {
  std::string bookmark_path;
  if (!get_bookmarked_path(bookmark_path)) {
    return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(false)));
  }

  bool has_permission = (access(bookmark_path.c_str(), W_OK) == 0);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(has_permission)));
}

// Method: requestWritePermission
static FlMethodResponse* request_write_permission() {
  // On Linux desktop, we don't need runtime permission dialogs
  // Just return the current write permission status
  return has_write_permission();
}

// MethodChannel handler
static void directory_bookmarks_plugin_handle_method_call(
    DirectoryBookmarksPlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  if (strcmp(method, "saveDirectoryBookmark") == 0) {
    response = save_directory_bookmark(args);
  } else if (strcmp(method, "resolveDirectoryBookmark") == 0) {
    response = resolve_directory_bookmark();
  } else if (strcmp(method, "saveFile") == 0) {
    response = save_file(args);
  } else if (strcmp(method, "readFile") == 0) {
    response = read_file(args);
  } else if (strcmp(method, "listFiles") == 0) {
    response = list_files();
  } else if (strcmp(method, "hasWritePermission") == 0) {
    response = has_write_permission();
  } else if (strcmp(method, "requestWritePermission") == 0) {
    response = request_write_permission();
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
