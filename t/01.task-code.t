use Test::More tests => 1;
use Test::Trap;

use App::Task;

diag("Testing App::Task $App::Task::VERSION");

trap {
    print "I am at depth 0\n";

    task "Foo" => sub {
        print "I am foo\nWho are you?\n";

        task "foo nested 1" => sub {
            print "Before: I (2) am still foo\nare you still you?\n";

            task "foo nested 2" => sub {
                print "I (3) am still foo\nare you still you?\n";
            };

            print "After: I (2) am still foo\nare you still you?\n";
        };

        task "foo nested 1 again" => sub { print "hi\n"; };

        print "AFTER: I am foo\nWho are you?\n";
    };

    task "Bar" => sub {
        print "I am bar\nAt least so far";

        task "bar nested 1" => sub {
            print "Before: I (2) am still bar\nAt least so far";

            task "bar nested 2" => sub {
                print "I (3) am still bar\nAt least so far";
            };

            print "After: I (2) am still bar\nAt least so far";
        };

        task "bar nested 1 again" => sub { print "hi"; };

        print "AFTER: I am finally bar\nAt least so far";
    };

    print "I also am at depth 0\n";
};

# printf()
# say()
# STDERR
# warn()
# return; == failed

diag( explain($trap) );
ok($trap);
