\#!/usr/bin/perl -I/home/phil/perl/cpan/DataTableText/lib/ -I/home/phil/perl/cpan/SvgSimple/lib/
\#-------------------------------------------------------------------------------
\# Wiring diagram
\# Philip R Brenan at appaapps dot com, Appa Apps Ltd Inc., 2024
\#-------------------------------------------------------------------------------
use v5.34;
package Silicon::Chip::Wiring;
our $VERSION = 20240308;
use warnings FATAL => qw(all);
use strict;
use Carp;
use Data::Dump qw(dump);
use Data::Table::Text qw(:all);
use Svg::Simple;
eval "use Test::More qw(no\_plan);" unless caller;

makeDieConfess;

my $debug = 0;                                                                  # Debug if set
sub debugMask {1}                                                               # Adds a grid to the drawing of a bus line

\#D1 Construct                                                                   # Create a Silicon chip wiring diagrams

sub new(%)                                                                      # New wiring diagram
 {my (%options) = @\_;                                                           # Options
  genHash(\_\_PACKAGE\_\_,                                                          # Wiring diagram
    %options,                                                                   # Options
    wires => \[\],                                                                # Wires on diagram
   );
 }

sub wire($%)                                                                    # New wire on wiring diagram
 {my ($D, %options) = @\_;                                                       # Diagram, options

     my ($x, $X, $y, $Y, $d) = @options{qw(x X y Y d)};
     defined($x) or confess "x";
     defined($y) or confess "y";
     defined($X) or confess "X";
     defined($Y) or confess "Y";
     $x == $X and $y == $Y and confess "Start and end of connection are in the same cell";
     $d //= 0;

     if ($x > $X)                                                                   # Swap into normal order
      {($x, $X) = ($X, $x);
       ($y, $Y) = ($Y, $y);
       $d = !$d;
      }

     my $w = genHash(__PACKAGE__,                                                  # Wire
       x => $x,                                                                    # Start x position of wire
       X => $X,                                                                    # End   x position of wire
       y => $y,                                                                    # Start y position of wire
       Y => $Y,                                                                    # End   y position of wire
       d => $d,                                                                    # The direction to draw first, x: 0, y:1
      );

     return undef unless $D->canLayX($w) and $D->canLayY($w);                      # Confirm we can lay the wire
     push $D->wires->@*, $w;                                                       # Append wire to diagram

     $w
    }

sub canLayX($$)                                                                 #P Confirm we can lay a wire in X
 {my ($D, $W) = @\_;                                                             # Drawing, wire
  my ($x, $y, $X, $Y, $d) = @$W{qw(x y X Y d)};

     for my $w($D->wires->@*)                                                      # Each wire
      {my ($xx, $yy, $XX, $YY, $dd) = @$w{qw(x y X Y d)};
       if ($x >= $xx && $x <= $XX or $X >= $xx && $X <= $XX)                       # Overlap with this wire in X
        {if ($d == 0 and $dd == 0)
          {return 0 if $Y == $YY;
           next;
          }
         if ($d == 0 and $dd == 1)
          {return 0 if $Y == $yy;
           next;
          }
         if ($d == 1 and $dd == 0)
          {return 0 if $y == $YY;
           next;
          }
         if ($d == 1 and $dd == 1)
          {return 0 if $y == $yy;
           next;
          }
        }
      }
     1                                                                             # Did not overlay any existing X segment
    }

sub canLayY($$)                                                                 #P Confirm we can lay a wire in Y
 {my ($D, $W) = @\_;                                                             # Drawing, wire
  my ($x, $y, $X, $Y, $d) = @$W{qw(x y X Y d)};

     for my $w($D->wires->@*)                                                      # Each wire
      {my ($xx, $yy, $XX, $YY, $dd) = @$w{qw(x y X Y d)};
       if ($y >= $yy && $y <= $YY or $y >= $YY && $y <= $yy or                     # Overlap with this wire in Y
           $Y >= $yy && $y <= $YY or $Y >= $YY && $Y <= $yy)
        {if ($d == 0 and $dd == 0)
          {return 0 if $X == $XX;
           next;
          }
         if ($d == 0 and $dd == 1)
          {return 0 if $X == $xx;
           next;
          }
         if ($d == 1 and $dd == 0)
          {return 0 if $x == $XX;
           next;
          }
         if ($d == 1 and $dd == 1)
          {return 0 if $x == $xx;
           next;
          }
        }
      }
     1                                                                             # Did not overlay any existing Y segment
    }

\#D1 Visualize                                                                   # Visualize a Silicon chip wiring diagrams

sub svg($%)                                                                     #P Draw the bus lines.
 {my ($D, %options) = @\_;                                                       # Wiring diagram, options
  my @defaults = (defaults=>                                                    # Default values
   {stroke\_width => 1,
    opacity      =>0.75,
   });

    my $xs = "darkRed"; my $ys = "darkBlue";                                       # x,y colors

     my $svg = Svg::Simple::new(@defaults, %options, grid=>debugMask ? 1 : 0);     # Draw each wire via Svg. Grid set to 1 produces a grid that can be helpful debugging layout problems

     for my $w($D->wires->@*)                                                      # Each wire in X
      {my ($x, $y, $X, $Y, $d) = @$w{qw(x y X Y d)};
       next if $x == $X;                                                           # Must occupy space in this dimension
       if ($d)
        {$svg->line(x1=>$x,   y1=>$Y+1/2, x2=>$X+1, y2=>$Y+1/2, stroke=>$xs);
        }
       else
        {$svg->line(x1=>$x,   y1=>$y+1/2, x2=>$X+1, y2=>$y+1/2, stroke=>$xs);
        }
      }

     for my $w($D->wires->@*)                                                      # Each wire in Y
      {my ($x, $y, $X, $Y, $d) = @$w{qw(x y X Y d)};
       next if $y == $Y;                                                           # Must occupy space in this dimension
       if ($d)
        {if ($y < $Y)
          {$svg->line(x1=>$x+1/2, y1=>$y,   x2=>$x+1/2, y2=>$Y+1,   stroke=>$ys);
          }
        elsif ($y > $Y)                                                            # Avoid drawing Y wires of length 1
          {$svg->line(x1=>$x+1/2, y1=>$Y,   x2=>$x+1/2, y2=>$y+1,   stroke=>$ys);
          }
        }
       else
        {if ($y > $Y)
          {$svg->line(x1=>$X+1/2, y1=>$y+1, x2=>$X+1/2, y2=>$Y,     stroke=>$ys);
          }
        elsif ($y < $Y)                                                            # Avoid drawing Y wires of length 1
          {$svg->line(x1=>$X+1/2, y1=>$y,   x2=>$X+1/2, y2=>$Y+1,   stroke=>$ys);
          }
        }
      }

     my $t = $svg->print;                                                          # Text of svg
     if (my $f = $options{file})                                                   # Optionally write to an svg file
      {owf(fpe(q(svg), $f, q(svg)), $t)
      }

     $t
    }

\#D0

\# Tests

if (1)
 {my $d = new;
  $d->wire(x=>1, y=>1, X=>3, Y=>1);
  $d->wire(x=>2, y=>1, X=>4, Y=>1);
  $d->svg(file=>"overX1");
 }

if (1)
 {my $d = new;
  $d->wire(x=>1, y=>1, X=>1, Y=>3);
  $d->wire(x=>1, y=>2, X=>1, Y=>4);
  $d->svg(file=>"overY1");
 }

if (1)                                                                          #Twire #Tnew
 {my $d = new;
  $d->wire(x=>1, y=>3, X=>3, Y=>1);
  $d->wire(x=>7, y=>3, X=>5, Y=>1);
  $d->wire(x=>1, y=>5, X=>3, Y=>7);
  $d->wire(x=>7, y=>5, X=>5, Y=>7);

     $d->wire(x=>1, y=>11, X=>3, Y=>9,  d=>1);
     $d->wire(x=>7, y=>11, X=>5, Y=>9,  d=>1);
     $d->wire(x=>1, y=>13, X=>3, Y=>15, d=>1);
     $d->wire(x=>7, y=>13, X=>5, Y=>15, d=>1);

     ok(!$d->wire(x=>1, y=>8, X=>2, Y=>10,  d=>1));
     $d->svg(file=>"square");
    }
