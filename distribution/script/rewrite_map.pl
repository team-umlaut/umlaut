#!/usr/bin/perl
$| = 1; # Turn off bufferingi
open LOG ,">>map_log";
while (<STDIN>) { 

   print LOG "Orig: " . $_ . " \n";
        s/>/%3E/g;
        s/</%3C/g;
        s/\//%2F/g;
        s/\\/%5C/g;
        s/ /\+/g;
        print $_;
   print LOG "Translated: " . $_ . " \n";
}
