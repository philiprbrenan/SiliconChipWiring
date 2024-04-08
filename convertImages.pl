#!/usr/bin/perl -I/home/phil/perl/cpan/DataTableText/lib/
#-------------------------------------------------------------------------------
# Post process images
# Philip R Brenan at appaapps dot com, Appa Apps Ltd Inc., 2024
#-------------------------------------------------------------------------------
use v5.34;
use warnings FATAL => qw(all);
use strict;
use Carp;
use Data::Dump qw(dump);
use Data::Table::Text qw(:all);
use GitHub::Crud qw(:all);

my $home  = currentDirectory;                                                   # Home folder
my $imgs  = fpd $home, qw(lib Silicon Chip);                                    # Images folder
my $svg   = fpd $imgs, qw(svg);                                                 # Svg folder
my $png   = fpd $imgs, qw(png);                                                 # Png folder
my $gds   = fpd $imgs, qw(gds);                                                 # Gds folder
my $user  = "philiprbrenan";                                                    # Userid
my $repo  = "SiliconChipWiring";                                                # Repo
my $token = $ARGV[1];                                                           # Github token

if ($ENV{GITHUB_TOKEN})                                                         # Change folders for github
 {$svg = q(svg/);
  $png = q(png/);
  $gds = q(gds/);
 }

makePath($png);                                                                 # Make png folder

my @f = searchDirectoryTreesForMatchingFiles $svg, qw(.svg);

for my $s(@f)                                                                   # Svg files
 {my $t = setFileExtension $s, q(png);
     $t = swapFilePrefix $t, $svg, $png;                                        # Matching png
  my $c = qq(cairosvg -o $t --output-width 10000 --output-height 10000 $s);
  say STDERR qq($c);
  say STDERR qx($c);
 }

writeFolderUsingSavedToken $user, $repo, "lib/Silicon/Chip/svg/", "svg/", $token;
writeFolderUsingSavedToken $user, $repo, "lib/Silicon/Chip/gds/", "gds/", $token;
writeFolderUsingSavedToken $user, $repo, "lib/Silicon/Chip/png/", "png/", $token;
