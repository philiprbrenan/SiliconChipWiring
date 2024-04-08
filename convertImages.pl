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

my $home  = q(/home/phil/perl/cpan/SiliconChipWiring/);                         # Home folder
my $svg   = fpd $home, qw(lib Silicon Chip svg);                                # Svg folder
my $png   = fpd $home, qw(lib Silicon Chip png);                                # Png folder
my $user  = "philiprbrenan";                                                    # Userid
my $repo  = "SiliconChipWiring";                                                # Repo
my $token = $ARGV[1];                                                           # Github token

makePath($png);                                                                 # Make png folder

my @f = searchDirectoryTreesForMatchingFiles(fpd($home, qw(lib Silicon Chip svg)), qw(.svg));

for my $s(@f)                                                                   # Svg files
 {my $t = setFileExtension $s, q(png);
     $t = swapFilePrefix $t, $svg, $png;                                        # Matching png
  say STDERR qx(cairosvg -o $t --output-width 10000 --output-height 10000 $s);
 }

writeFolderUsingSavedToken $user, $repo, "lib/Silicon/Chip/svg/", "svg/", $token;
writeFolderUsingSavedToken $user, $repo, "lib/Silicon/Chip/gds/", "gds/", $token;
writeFolderUsingSavedToken $user, $repo, "lib/Silicon/Chip/png/", "png/", $token;
