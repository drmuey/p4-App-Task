use Test::More tests => 1;
use Test::Trap;

use App::Task;

trap {    # this hides system() :/
    print "I am at depth 0\n";

    task "first level arrayref beginning" => [ $^X, "-e", 'print "pre oh hai 1";' ];
    task "second level" => sub {
        task "second level arrayref beginning" => [ $^X, "-e", 'print "pre oh hai 2";' ];
        task "third level" => sub {
            task "third level arrayref beginning" => [ $^X, "-e", 'print "pre oh hai 3";' ];
            task "fourth level" => sub {
                task "fourth level arrayref" => [ $^X, "-e", 'print "pre oh hai 4";' ];
            };
            task "third level arrayref beginning" => [ $^X, "-e", 'print "pst oh hai 3";' ];
        };
        task "second level arrayref beginning" => [ $^X, "-e", 'print "pst oh hai 2";' ];
    };
    task "first level arrayref end" => [ $^X, "-e", 'print "pst oh hai 1";' ];

    print "I also am at depth 0\n";
};

# failure soft
# fatal => 1

diag( explain($trap) );
ok($trap);
