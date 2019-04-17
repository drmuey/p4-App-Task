package App::Task;

use strict;
use warnings;

use Text::OutputFilter;

our $VERSION = '0.01';
our $depth   = 0;
our $level   = 0;

sub import {
    no strict 'refs';    ## no critic
    *{ caller() . '::task' } = \&task;
}

our $steps      = {};
our $prev_depth = 1;

sub _nl { local $depth = 0; print "\n" }

sub _sys {
    my @cmd = @_;

    my $rv = system(@cmd) ? 0 : 1;    # TODO: indent **line at a time** i.e. not run it all and dump it all at once

    _nl();

    return $rv;
}

sub _escape {
    my ($str) = @_;

    $str =~ s/\\/\\\\/g;
    $str =~ s/\n/\\n/g;
    $str =~ s/\t/\\t/g;

    return $str;
}

sub _indent {
    my ($string) = @_;

    warn "_indent() called outside of task()\n" if $depth < 0;
    my $i = $depth <= 0 ? "" : "    " x $depth;

    $string =~ s/\n/\n$i/msg;
    return "$i$string";
}

sub task($$) {
    my ( $msg, $code, $cmdhr ) = @_;
    chomp($msg);

    local *STDOUT = *STDOUT;
    local *STDERR = *STDERR;

    open( local *ORIGOUT, ">&", \*STDOUT );
    open( local *ORIGERR, ">&", \*STDERR );

    # close STDOUT;
    # close STDERR;

    ORIGOUT->autoflush();
    ORIGERR->autoflush();
    my $o = tie( *STDOUT, "Text::OutputFilter", 0, \*ORIGOUT, \&_indent );
    my $e = tie( *STDERR, "Text::OutputFilter", 0, \*ORIGERR, \&_indent );

    my $task = $code;
    my $type = ref($code);
    if ( $type eq 'ARRAY' ) {
        my $disp = join " ", map {
            $_ = _escape($_);
            if (m/ /) { s/'/\\'/g; $_ = "'$_'" }
            $_
        } @{$code};
        if ( $ENV{"App_Task_DRYRUN"} ) {
            $task = sub { print "(DRYRUN) ＞＿ $disp\n" };
        }
        else {
            $task = $cmdhr->{fatal} ? sub { _sys( @{$code} ) or die "`$disp` did not exit cleanly: $?\n" } : sub { _sys( @{$code} ) };
        }

    }
    elsif ( !$type ) {
        my $disp = _escape($code);
        if ( $ENV{"App_Task_DRYRUN"} ) {
            $task = sub { print "(DRYRUN) ＞＿ $disp\n" };
        }
        else {
            $task = $cmdhr->{fatal} ? sub { _sys($code) or die "`$disp` did not exit cleanly: $?\n" } : sub { _sys($code) };
        }
    }

    my $cur_depth = $depth;
    local $depth = $depth + 1;
    local $level = $level + 1;

    $steps->{$depth} = defined $steps->{$depth} ? $steps->{$depth} + 1 : 1;

    if ( $prev_depth > $cur_depth ) {
        for my $k ( keys %{$steps} ) {
            delete $steps->{$k} if $k > $depth;
        }
    }

    $prev_depth = $depth;

    my $pre = $steps->{$depth} ? "[$level.$steps->{$depth}]" : "[$level]";

    {
        local $depth = $depth - 1;
        print "➜➜➜➜ $pre $msg …";
        _nl() if $level == 1 && $steps->{ $depth + 1 } == 1;    # for the first header :/ why must this be done?
    }

    my $ok = $task->();

    {
        local $depth = $depth - 1;
        if ($ok) {
            print " … $pre done ($msg).\n";
        }
        else {
            warn " … $pre failed ($msg).\n";
        }
    }

    if ( $depth < 2 ) {
        undef $o;
        untie *STDOUT;
        undef $e;
        untie *STDERR;
    }

    return $ok;
}

1;

__END__

=head1 NAME

App::Task - Nest tasks w/ indented output and pre/post headers

=head1 VERSION

This document describes App::Task version 0.01

=head1 SYNOPSIS

    use App::Task;

    task "…" => sub {};
    task "…" => ["system","args","here"], {fatal => 1};
    task "…" => "system command here";

Nested

    task "…" => sub {
        task "…" => sub {
            task "…" => sub { … };
        };
        task "…" => sub { … };
        task "…" => sub {
            task "…" => sub {
                task "…" => sub { …  };
            };
        };
    }

=head1 DESCRIPTION

This allows us to create scripts that organize tasks together and have their output be organized similarly and with added clarity.

It does this by wrapping each task in a starting/ending output line, indenting output congruent with nested C<task()> depth.

For example, say this:

    system(…);
    foo();
    system(…,…);
    say test_foo() ? "foo is good" : "foo is down";

outputs this:

    Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
    Nunc mi ipsum faucibus vitae aliquet nec ullamcorper sit amet.
    Facilisi morbi tempus iaculis urna id volutpat lacus laoreet.
    Ullamcorper eget nulla facilisi etiam dignissim diam.
    Maecenas volutpat blandit aliquam etiam erat velit scelerisque in dictum.
    foo is good

Nothing wrong with that but it could be easier to process visually, so if we C<task()>’d it up a bit like this:

    task "setup foo" => sub {
        task "configure foo" => "…";
        task "run foo" => \&foo;
    };

    task "finalize foo" => sub {
        task "enable barring" => […,…];
        task "verify foo" => sub {
            say test_foo() ? "foo is good" : "foo is down";
        };
    };

Now you get:

    ➜➜➜➜ [1.1] setup foo …
        ➜➜➜➜ [2.1] configure foo …
            Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
         … done (configure foo).

        ➜➜➜➜ [2.2] run foo …
            Nunc mi ipsum faucibus vitae aliquet nec ullamcorper sit amet.
            Facilisi morbi tempus iaculis urna id volutpat lacus laoreet.
         … done (run foo).

     … done (setup foo).

    ➜➜➜➜ [1.2] finalize foo …
        ➜➜➜➜ [2.1] enable barring …
            Ullamcorper eget nulla facilisi etiam dignissim diam.
            Maecenas volutpat blandit aliquam etiam erat velit scelerisque in dictum.
         … done (enable barring).

        ➜➜➜➜ [2.2] verify foo …
            foo is down
         … failed (verify foo).

     … done (finalize foo).

=head1 INTERFACE

Each variant has a pre/post heading and indented output.

=head2 task NAME => CODEREF

If CODEREF returns true the post heading will be “done”, if it returns false it will be “failed”.

To make CODEREF fatal just throw an exception.

=head2 task NAME => CMD_STRING

CMD_STRING is a string suitable for C<system(CMD_STRING)>.

If the command exits clean the post heading will be “done”, if it exits unclean it will be “failed”.

To make CMD_STRING exiting unclean be fatal you can set fatal to true in the optional 3rd argument to task:

    task "prep fiddler" => "/usr/bin/fiddler prep"; # will continue on unclean exit
    task "create fiddler" => "/usr/bin/fiddler new", { fatal => 1 }; # will die on unclean exit

=head2 task NAME => CMD_ARRAYREF

task NAME => CMD_ARRAYREF is a string suitable for C<system(@{CMD_ARRAYREF})>.

If the command exits clean the post heading will be “done”, if it exits unclean it will be “failed”.

To make CMD_STRING exiting unclean be fatal you can set fatal to true in the optional 3rd argument to task:

    task "prep fiddler" => ["/usr/bin/fiddler", "prep"]; # will continue on unclean exit
    task "create fiddler" => ["/usr/bin/fiddler", "new"], { fatal => 1 }; # will die on unclean exit

=head1 DIAGNOSTICS

Throws no warnings or errors of its own.

=head1 CONFIGURATION AND ENVIRONMENT

App::Task requires no configuration files or environment variables.

=head1 DEPENDENCIES

L<IPC::Open3::Utils>, L<Tie::Handle>

=head1 INCOMPATIBILITIES AND LIMITATIONS

The indentation is not carried across forks (patches to not use Tie welcome!). That means, for example, if you call system() directly inside a task it will not be indented.

=head1 BUGS AND FEATURES

Please report any bugs or feature requests (and a pull request for bonus points)
 through the issue tracker at L<https://github.com/drmuey/p5-App-Task/issues>.

=head1 AUTHOR

Daniel Muey  C<< <http://drmuey.com/cpan_contact.pl> >>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2018, Daniel Muey C<< <http://drmuey.com/cpan_contact.pl> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
