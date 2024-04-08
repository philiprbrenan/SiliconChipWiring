#!/usr/bin/perl -I/home/phil/perl/cpan/DataTableText/lib/
#-------------------------------------------------------------------------------
# Post process SVG images to PNG.  Place images for use in documentation.
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
my $dir   = fpd qw(lib Silicon Chip);                                           # Target folder for images
my $imgs  = fpd $home, $dir;                                                    # Images source folder
   $imgs  = $home if $ENV{GITHUB_TOKEN};                                        # Change folders for github
my $svg   = fpd $imgs, qw(svg);                                                 # Svg folder
my $png   = fpd $imgs, qw(png);                                                 # Png folder
my $gds   = fpd $imgs, qw(gds);                                                 # Gds folder
my ($user, $repo) =
  split m(/), $ENV{GITHUB_REPOSITORY} // "philiprbrenan/SiliconChipWiring";     # User / repo

makePath($png);                                                                 # Make png folder

my @f = searchDirectoryTreesForMatchingFiles $svg, qw(.svg);                    # Svg files from which we make png files

for my $s(@f)                                                                   # Svg files
 {my $t = setFileExtension $s, q(png);
     $t = swapFilePrefix $t, $svg, $png;                                        # Matching png
  my $c = qq(cairosvg -o $t --output-width 10000 --output-height 10000 $s);
  say STDERR qq($c);
  say STDERR qx($c);
 }

for my $x(qw(gds png svg))                                                      # Upload images to target location
 {say STDERR dump([$user, $repo, fpd($home, $dir, $x), $x]);
  writeFolderUsingSavedToken $user, $repo, fpd($dir, $x), $x;
 }
