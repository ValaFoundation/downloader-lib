#!/usr/bin/env bash
set -euo pipefail

# Colors for better terminal output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}==> Initializing Vala Library Template manager for Vala...${NC}"

# 1. Check if the user is running the script in the root of a Meson project
if [ ! -f "meson.build" ]; then
    echo -e "${RED}[Error] 'meson.build' file not found in the current directory.${NC}"
    echo -e "Make sure you are running this script in the root folder of your Vala application."
    exit 1
fi

# 2. Create the subprojects folder if it doesn't exist yet
if [ ! -d "subprojects" ]; then
    echo -e "Creating ${BLUE}subprojects/${NC} directory..."
    mkdir "subprojects"
fi

# 3. Generate the .wrap file
WRAP_FILE="subprojects/vala_testcases.wrap"
echo -e "Generating wrap file ${BLUE}${WRAP_FILE}${NC}..."

cat << 'EOF' > "$WRAP_FILE"
[wrap-git]
url = https://github.com/JanGalek/vala-testcases.git
revision = v1.1.0
depth = 1

[provide]
dependency_name = vala_testcases
EOF

TEST_MAIN_FILE="tests/main.vala"
echo -e "Generating main test file ${BLUE}${TEST_MAIN_FILE}${NC}..."

cat << 'EOF' > "$TEST_MAIN_FILE"
using GLib;
using Gee;

int main (string[] args) {

    Testcases.BaseTest.saved_commands = new Gee.ArrayList<Testcases.TestCommand> ();
    Test.init (ref args);

    Testcases.register_test_suite<AppTests.ExampleTest> ();


    return Test.run ();
}

EOF

TEST_EXAMPLE_TEST_FILE="tests/example_test.vala"
echo -e "Generating example test file ${BLUE}${TEST_EXAMPLE_TEST_FILE}${NC}..."

cat << 'EOF' > "$TEST_EXAMPLE_TEST_FILE"
namespace AppTests {
    using GLib;
    using Testcases;

    public class ExampleTest : BaseTest {
        construct {
            add_test ("matematika", test_matematika);
            add_test ("text", test_text);
        }

        public void test_matematika () {
            assert (1 + 1 == 2);
        }

        public void test_text () {
            assert ("vala".length == 4);
        }
    }
}

EOF

TEST_MESON_FILE="tests/meson.build"
echo -e "Generating meson build file ${BLUE}${TEST_MESON_FILE}${NC}..."

cat << 'EOF' > "$TEST_MESON_FILE"
test_env = environment()
test_sources = files(
  'main.vala',
  'example_test.vala',
)


test_exe = executable('tests',
  test_sources,
  dependencies: vala_lib_deps,
  link_with: vala_lib,
  include_directories: [include_directories('../src')],
  vala_args: ['--target-glib=2.58'],
)

test('Unit Tests', test_exe, env: test_env, protocol: 'tap')

EOF


echo -e "${GREEN}[Done] Wrap file has been successfully created.${NC}\n"

# 4. Instructions for the developer on how to proceed
echo -e "${BLUE}Now edit your main 'meson.build' and add the dependency:${NC}"
echo -e "--------------------------------------------------------"
echo -e "vala_testcases_dep = dependency('vala_testcases', fallback: ['vala_testcases', 'vala_testcases_dep'])"
echo -e ""
echo -e "executable("
echo -e "  'your-binary-name',"
echo -e "  'your-source-files.vala',"
echo -e "  dependencies: [ dependency('glib-2.0'), dependency('gio-2.0'), ${GREEN}vala_testcases_dep${NC} ]"
echo -e ")"
echo -e "subdir('tests')"
echo -e "--------------------------------------------------------"
echo -e "Then just build the project using: ${GREEN}meson setup build && meson compile -C build${NC}"
