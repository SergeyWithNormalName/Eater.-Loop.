extends RefCounted

func load_project_config() -> ConfigFile:
    var cfg = ConfigFile.new()
    var err = cfg.load("res://project.godot")
    if err != OK:
        return null
    return cfg

func list_files(root: String, extension: String, exclude_dirs: Array[String], exclude_path_substrings: Array[String] = []) -> Array[String]:
    var results: Array[String] = []
    _list_files_recursive(root, extension, exclude_dirs, exclude_path_substrings, results)
    results.sort()
    return results

func _list_files_recursive(root: String, extension: String, exclude_dirs: Array[String], exclude_path_substrings: Array[String], results: Array[String]) -> void:
    var dir = DirAccess.open(root)
    if dir == null:
        return
    dir.list_dir_begin()
    var name = dir.get_next()
    while name != "":
        if name.begins_with("."):
            name = dir.get_next()
            continue
        var path = root.path_join(name)
        if dir.current_is_dir():
            if _should_skip_dir(name, path, exclude_dirs, exclude_path_substrings):
                name = dir.get_next()
                continue
            _list_files_recursive(path, extension, exclude_dirs, exclude_path_substrings, results)
        else:
            if name.ends_with(extension):
                if not _path_has_excluded_substring(path, exclude_path_substrings):
                    results.append(path)
        name = dir.get_next()
    dir.list_dir_end()

func _should_skip_dir(name: String, path: String, exclude_dirs: Array[String], exclude_path_substrings: Array[String]) -> bool:
    if exclude_dirs.has(name):
        return true
    return _path_has_excluded_substring(path, exclude_path_substrings)

func _path_has_excluded_substring(path: String, exclude_path_substrings: Array[String]) -> bool:
    for fragment in exclude_path_substrings:
        if path.find(fragment) != -1:
            return true
    return false
