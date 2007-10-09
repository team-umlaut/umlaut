#!/usr/bin/perl
$| = 1; # Turn off bufferingi
while (<STDIN>) { 

        s/>/%3E/g;
        s/</%3C/g;
        s/\//%2F/g;
        s/\\/%5C/g;
        s/ /\+/g;
        print $_;
}
