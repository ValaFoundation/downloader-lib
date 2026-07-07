using GLib;
using Gee;

int main (string[] args) {

    Testcases.BaseTest.saved_commands = new Gee.ArrayList<Testcases.TestCommand> ();
    Test.init (ref args);

    Testcases.register_test_suite<AppTests.ExampleTest> ();


    return Test.run ();
}

