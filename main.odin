package main

import "core:fmt"
import "core:os"
import "core:strings"

main :: proc() {
	argc := len(os.args)
	if argc < 2 {
		fmt.println("Usage: odin-new <Project Name>")
		return
	}

	sb := strings.builder_make(context.temp_allocator)
	defer strings.builder_destroy(&sb)

	// Make Project Directory
	project_name := os.args[1]
	project_path := strings.concatenate({"./", project_name})
	if !os.is_directory(project_path) {
		mkdir_err := os.make_directory(project_name)
		if mkdir_err != nil {
			fmt.panicf("ERR make project directory: %v", mkdir_err)
		}
	}

	// Change to project directory
	os.change_directory(project_name)

	// Make main.odin
	main_contents := strings.concatenate({"package main", "\n\n", "main :: proc() {}"})
	f, err := os.open("main.odin", {.Create, .Write, .Trunc})
	os.write_string(f, main_contents)
	os.close(f)

	// Copy base and core to project directory
	proc_desc := os.Process_Desc{}
	proc_desc.command = {"odin", "root"}
	state, stdout, stderr, exec_err := os.process_exec(proc_desc, context.temp_allocator)
	if exec_err != nil {
		fmt.panicf("ERR run `odin root`: %v", exec_err)
	}
	odinroot := strings.clone_from_bytes(stdout)

	if !os.is_directory("odin") {
		os.make_directory("odin")
	}
	project_odin_path := strings.join({project_name, "odin"}, "/")
	base_package_path := strings.join({odinroot, "base"}, "/")
	core_package_path := strings.join({odinroot, "core"}, "/")
	os.copy_directory_all(project_odin_path, base_package_path)
	os.copy_directory_all(project_odin_path, core_package_path)

	// .git
	git_exec := os.Process_Desc{}
	git_exec.command = {"git", "init"}
	state, stdout, _, exec_err = os.process_exec(git_exec, context.temp_allocator)

	strings.write_string(&sb, "build/")
	strings.write_string(&sb, "\n")
	strings.write_string(&sb, "odin/")
	strings.write_string(&sb, "\n")
	strings.write_string(&sb, ".DS_Store")
	strings.write_string(&sb, "\n")
	f, err = os.open(".gitignore", {.Create, .Write, .Trunc})
	os.write_string(f, strings.to_string(sb))
	os.close(f)
	strings.builder_reset(&sb)


	// Run script
	strings.write_string(&sb, "mkdir -p build\n")
	strings.write_string(&sb, "pushd build > /dev/null\n")
	strings.write_string(&sb, "odin run ../ -out:odin-new -debug -strict-style -vet\n")
	strings.write_string(&sb, "popd > /dev/null")
	f, err = os.open("run.sh", {.Create, .Write, .Trunc})
	os.write_string(f, strings.to_string(sb))
	os.close(f)
	strings.builder_reset(&sb)

	os.chmod("run.sh", {.Read_User, .Write_User, .Execute_User})
}

