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
		fmt.printfln("Created project: %s", project_name)
	}

	// Change to project directory
	os.change_directory(project_name)

	// Make main.odin
	main_contents := strings.concatenate({"package main", "\n\n", "main :: proc() {}"})
	f, err := os.open("main.odin", {.Create, .Write, .Trunc})
	os.write_string(f, main_contents)
	os.close(f)
	fmt.println("Create main.odin")

	// Copy base and core to project directory
	proc_desc := os.Process_Desc{}
	proc_desc.command = {"odin", "root"}
	_, stdout, _, exec_err := os.process_exec(proc_desc, context.temp_allocator)
	if exec_err != nil {
		fmt.panicf("ERR run `odin root`: %v", exec_err)
	}
	odinroot := strings.clone_from_bytes(stdout)
	fmt.printfln("Found `odin` at %s", odinroot)

	project_rel_odin_path := "odin"
	if !os.is_directory(project_rel_odin_path) {
		os.make_directory(project_rel_odin_path)
	}
	base_package_path := strings.concatenate({odinroot, "base"})
	core_package_path := strings.concatenate({odinroot, "core"})
	copy_err := os.copy_directory_all(project_rel_odin_path, base_package_path)
	if copy_err == nil {
		fmt.println("Copied in odin/base")
	} else {
		fmt.panicf("ERR copy `%s` to `%s`: %v", base_package_path, project_rel_odin_path, copy_err)
	}
	copy_err = os.copy_directory_all(project_rel_odin_path, core_package_path)
	if copy_err == nil {
		fmt.println("Copied in odin/core")
	}

	// .git
	git_exec := os.Process_Desc{}
	git_exec.command = {"git", "init"}
	_, stdout, _, exec_err = os.process_exec(git_exec, context.temp_allocator)
	fmt.println("Initialized git")
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
	fmt.println("Added gitignore")


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

