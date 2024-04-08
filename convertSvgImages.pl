#!/usr/bin/perl -I/home/phil/perl/cpan/DataTableText/lib/ -I/home/phil/perl/cpan/GitHubCrud/lib
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

$ENV{GITHUB_REPOSITORY} = "philiprbrenan/SiliconChipWiring";                    # Pretend we are on github
say STDERR dump(postProcessImagesForDocumentation2);
