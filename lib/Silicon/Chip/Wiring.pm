#!/usr/bin/perl -I/home/phil/perl/cpan/DataTableText/lib/ -I/home/phil/perl/cpan/SvgSimple/lib/  -I/home/phil/perl/cpan/Math-Intersection-Circle-Line/lib
#!/usr/bin/perl -I/home/phil/perl/cpan/DataTableText/lib/ -I/home/phil/perl/cpan/SvgSimple/lib/  -I/home/phil/perl/cpan/Math-Intersection-Circle-Line/lib
#-------------------------------------------------------------------------------
# Wiring up a silicon chip to transform software into hardware.
# Philip R Brenan at appaapps dot com, Appa Apps Ltd Inc., 2024
#-------------------------------------------------------------------------------
use v5.34;
package Silicon::Chip::Wiring;
our $VERSION = 20240331;
use warnings FATAL => qw(all);
use strict;
use Carp qw(confess cluck);
use Data::Dump qw(dump);
use Data::Table::Text qw(:all);
use Svg::Simple;
use GDS2;

#  Vertical
#  Y cross bar  There are 4 sub levels within each wiring level. The sub levels are connected by the vertical vias described in the next comment.
#  Insulation   The sea of gates is formed at level 0 and is pre-manufactured by the wafer vendor.  Our job is just to connect them.
#  X cross bar
#  Insulation

#  Horizontal
#  ..y        Each cell is divided into 16 sub cells that are arranged to permit
#  xxyx       the via (V) connect with the X and Y crossbars.  There is a layer
#  ..y.       of insulation under each of the X and Y cross bars making 4 sub
#  V.y.       levels per level.  The dots . represent areas with no metal so
#             they do not conduct unless metal is added during lithography.
# During wire connection connection, the . next to V are assumed to have metal so that the via can connect to the crossbars.

makeDieConfess;

my $debug = 0;                                                                  # Debug if set
sub debugMask {1}                                                               # Adds a grid to the drawing of a bus line

#D1 Construct                                                                   # Create a Silicon chip wiring diagram on one or more levels as necessary to make the connections requested.

sub new(%)                                                                      # New wiring diagram.
 {my (%options) = @_;                                                           # Options

  my ($w, $h) = @options{qw(width height)};
  defined($w) or confess "w";
  defined($h) or confess "h";

  my $d = genHash(__PACKAGE__,                                                  # Wiring diagram
    options=> \%options,                                                        # Creation options
    log    => $options{log},                                                    # Log activity if true
    width  => $options{width},                                                  # Width of chip
    height => $options{height},                                                 # Height of chip
    wires  => [],                                                               # Wires on diagram
    levels => 0,                                                                # Levels in use
    levelX => {},                                                               # {level}{x}{y} - available cells in X  - used cells are deleted. Normally if present the cell, if present has a positive value.  If it has a negative it is a temporary addition for the purpose of connecting the end points of the wires to the vertical vias.
    levelY => {},                                                               # {level}{x}{y} - available cells in Y
   );

  $d
 }

sub wire($$$$$%)                                                                # New wire on a wiring diagram.
 {my ($diagram, $x, $y, $X, $Y, %options) = @_;                                 # Diagram, start x, start y, end x, end y, options

  defined($x) or confess "x";
  defined($y) or confess "y";
  defined($X) or confess "X";
  defined($Y) or confess "Y";
  $x == $X and $y == $Y and confess "Start and end of connection are in the same cell";
  lll "Wire", scalar($diagram->wires->@*) if $diagram->options->{debug};

  my $w = genHash(__PACKAGE__,                                                  # Wire
    x => $x,                                                                    # Start x position of wire
    X => $X,                                                                    # End   x position of wire
    y => $y,                                                                    # Start y position of wire
    Y => $Y,                                                                    # End   y position of wire
    l => undef,                                                                 # Level on which wire is drawn
    n => $options{n}//'',                                                       # Optional name
    p => [],                                                                    # Path from start to finish
   );

  push $diagram->wires->@*, $w;                                                 # Save wire
  $w                                                                            # The wire
 }

sub resetLevels($%)                                                             #P Reset all the levels so we can layout again
 {my ($diagram, %options) = @_;                                                 # Diagram, options

  $diagram->levels = 0;
  $diagram->levelX = {};
  $diagram->levelY = {};
 }

sub layout($%)                                                                  # Layout the wires using Java
 {my ($diagram, %options) = @_;                                                 # Diagram, options
  my $d = $diagram;                                                             # Shorten name
     $d->resetLevels;                                                           # Reset for new layout

  my @w = $d->wires->@*;
  my $i = temporaryFile;                                                        # Specification of wires to be made
  my $o = temporaryFile;                                                        # Details of connections made
  my $j = q(Diagram.java);                                                      # Code to produce wiring diagram

  owf($i, join "\n", 4*$d->width, 4*$d->height, scalar(@w),                     # Divide each cell into 4 sub cells == pixels
          map {4*$_}
          map {@$_{qw(x y X Y)}} @w);

  owf($j, $diagram->java);                                                      # Run code to produce wiring diagram
  my $r = qx(java $j < $i > $o);
  say STDERR $r if $r =~ m(\S);

  my @o = map {eval $_} readFile $o;                                            # Read wiring diagram
  @o == @w or confess "Length mismatch";
  unlink $i, $o, $j;

  for my $i(keys @w)                                                            # Parse wiring diagram
   {my $w = $w[$i];
    my $o = $o[$i];
    $w->l = $$o[0];
    $w->p = $$o[1];
    my @p = $w->p->@*;
    for my $j(1..$#p)                                                           # Direction indicator
     {my ($p, $q) = ($p[$j-1], $p[$j]);
      $$p[2] = $$p[0] == $$q[0] ? 1 : 0;
     }
   }

  $d->levels = maximum map {$_->l} $d->wires->@*;                               # Number of levels
 }

sub numberOfWires($%)                                                           # Number of wires in the diagram
 {my ($D, %options) = @_;                                                       # Diagram, options
  scalar $D->wires->@*
 }

sub length($$)                                                                  # Length of a wire in a diagram
 {my ($D, $w) = @_;                                                             # Diagram, wire
  scalar $w->p->@*                                                              # The length of the path
 }

sub totalLength($)                                                              # Total length of wires
 {my ($d) = @_;                                                                 # Diagram
  my @w = $d->wires->@*;
  my $l = 0; $l += $d->length($_) for @w;                                       # Add length of each wire
  $l
 }

my sub distance($$$$)                                                           # Manhattan distance between two points
 {my ($x, $y, $X, $Y) = @_;                                                     # Start x, start y, end x, end y
  abs($X - $x) + abs($Y - $y)
 }

#D1 Shortest Path                                                               # Find the shortest path using compiled code

sub java                                                                        #P Using Java as it is faster than Perl to layout the connections
 {<<END
//------------------------------------------------------------------------------
// Wiring diagram
// Philip R Brenan at appaapps dot com, Appa Apps Ltd Inc., 2024
//------------------------------------------------------------------------------
import java.util.*;

class Diagram                                                                   // Wiring diagram
 {final static Scanner S = new Scanner(System.in);                              // Read the input file
  final int width;                                                              // Width of diagram
  final int height;                                                             // Height of diagram
  final Stack<Level> levels = new Stack<>();                                    // Wires levels in the diagram
  final Stack<Wire>   wires = new Stack<>();                                    // Wires in the diagram
  public Diagram(int Width, int Height)                                         // Diagram
   {width = Width; height = Height;
    new Level();                                                                // A diagram has at least one level
   }

  class Level                                                                   // A level within the diagram
   {final boolean[][]ix = new boolean[width][height];                           // Moves in x permitted
    final boolean[][]iy = new boolean[width][height];                           // Moves in y permitted

    public Level()                                                              // Diagram
     {for   (int i = 0; i < width;  ++i)                                        // The initial moves allowed
       {for (int j = 0; j < height; ++j)
         {if (j % 4 == 2) ix[i][j] = true;                                      // This arrangement leaves room for the vertical vias that connect the levels to the sea of gates on level 0
          if (i % 4 == 2) iy[i][j] = true;
         }
       }
      levels.push(this);                                                        // Add level to diagram
     }

    public String toString()                                                    // Display a level as a string
     {final StringBuilder s = new StringBuilder();
      for  (int j = 0; j < height; ++j)
       {for(int i = 0; i < width;  ++i)
         {final boolean x = ix[i][j], y = iy[i][j];
          final char c = x && y ? '3' : y ? '2' : x ? '1' : ' ';
          s.append(c);
         }
        s.append(System.lineSeparator());
       }
      return s.toString();
     }
   }

  class Pixel                                                                   // Pixel on the diagram
   {final int x, y;
    public Pixel(int X, int Y) {x = X; y = Y;}
    public String toString() {return "["+x+","+y+"]";}
   }

  class Search                                                                  // Find a shortest path between two points in this level
   {final Level level;                                                          // The level we are on
    final Pixel start;                                                          // Start of desired path
    final Pixel finish;                                                         // Finish of desired path
    Stack<Pixel>    path = new Stack<>();                                       // Path from start to finish
    Stack<Pixel>       o = new Stack<>();                                       // Cells at current edge of search
    Stack<Pixel>       n = new Stack<>();                                       // Cells at new edge of search
    short[][]          d = new short[width][height];                            // Distance at each cell
    Integer        turns = null;                                                // Number of turns along path
    short          depth = 1;                                                   // Length of path
    boolean       found;                                                        // Whether a connection was found or not

    void printD()                                                               // Print state of current search
     {System.err.print("    ");
      for  (int x = 0; x < width; ++x)                                          // Print column headers
       {System.err.print(String.format("%2d ", x));
       }
      System.err.println("");

      for  (int y = 0; y < height; ++y)                                         // Print body
       {System.err.print(String.format("%3d ", y));
        for(int x = 0; x < width;  ++x)
         {System.err.print(String.format("%2d ", d[x][y]));
         }
        System.err.println("");
       }
     }

    boolean around(int x, int y)                                                // Check around the specified point
     {if (x < 0 || y < 0 || x >= width || y >= height) return false;            // Trying to move off the board
       if ((level.ix[x][y] || level.iy[x][y]) && d[x][y] == 0)                  // Located a new unclassified cell
       {d[x][y] = depth;                                                        // Set depth for cell and record is as being at that depth
        n.push(new Pixel(x, y));                                                // Set depth for cell and record is as being at that depth
        return x == finish.x && y == finish.y;                                  // Reached target
       }
      return false;
     }

    boolean search()                                                            // Breadth first search
     {for(depth = 2; depth < 999999; ++depth)                                   // Depth of search
       {if (o.size() == 0) break;                                               // Keep going until we cannot go any further

        n = new Stack<>();                                                      // Cells at new edge of search

        for (Pixel p : o)                                                       // Check cells adjacent to the current border
         {if (around(p.x,   p.y))    return true;
          if (around(p.x-1, p.y))    return true;
          if (around(p.x+1, p.y))    return true;
          if (around(p.x,   p.y-1))  return true;
          if (around(p.x,   p.y+1))  return true;
         }
        o = n;                                                                  // The new frontier becomes the settled frontier
       }
      return false;                                                             // Unable to place wire
     }

    boolean step(int x, int y, int D)                                           // Step back along path from finish to start
     {if (x <  0     || y <  0)      return false;                              // Preference for step in X
      if (x >= width || y >= height) return false;                              // Step is viable?
      return d[x][y] == D;
     }

    void path(boolean favorX)                                                   // Finds a shortest path and returns the number of changes of direction and the path itself
     {int x = finish.x, y = finish.y;                                           // Work back from end point
      final short N = d[x][y];                                                  // Length of path
      final Stack<Pixel> p = new Stack<>();                                     // Path
      p.push(finish);
      Integer s = null, S = null;                                               // Direction of last step
      int c = 0;                                                                // Number of changes
      for(int D = N-1; D >= 1; --D)                                             // Work backwards
       {final boolean f = favorX ? s != null && s == 0 : s == null || s == 0;   // Preferred direction
        if (f)                                                                  // Preference for step in X
         {if      (step(x-1, y, D)) {x--; S = 0;}
          else if (step(x+1, y, D)) {x++; S = 0;}
          else if (step(x, y-1, D)) {y--; S = 1;}
          else if (step(x, y+1, D)) {y++; S = 1;}
          else stop("Cannot retrace");
         }
        else
         {if      (step(x, y-1, D)) {y--; S = 1;}                               // Preference for step in y
          else if (step(x, y+1, D)) {y++; S = 1;}
          else if (step(x-1, y, D)) {x--; S = 0;}
          else if (step(x+1, y, D)) {x++; S = 0;}
          else stop("Cannot retrace");
         }
        p.push(new Pixel(x, y));
        if (s != null && S != null && s != S) ++c ;                             // Count changes of direction
        s = S;                                                                  // Continue in the indicated direction
       }
      if (turns == null || c < turns) {path = p; turns = c; found = true;}      // Record path with fewest turns so far
     }

    void findShortestPath()                                                     // Shortest path
     {final int x = start.x, y  = start.y;

      o.push(start);                                                            // Start
      d[x][y] = 1;                                                              // Visited start

      if (!search()) return;                                                    // Return empty list if there is no path from the start to the finish
      path(false);
      path(true);
     }

    void setIx(int x, int y, boolean v)                                         // Set a temporarily possible position
     {if (x < 0 || y < 0 || x >= width || y >= height) return;
      level.ix[x][y] = v;
     }

    void setIy(int x, int y, boolean v)                                         // Set a temporarily possible position
     {if (x < 0 || y < 0 || x >= width || y >= height) return;
      level.iy[x][y] = v;
     }

    Search(Level Level, Pixel Start, Pixel Finish)                              // Search for path along which to place wire
     {level = Level; start = Start; finish = Finish;
      final int x = start.x, y = start.y, X = finish.x, Y = finish.y;

      if (x < 0 || y < 0)                                                       // Validate start and finish
        stop("Start out side of diagram", x, y);

      if (x >= width || y >= height)
        stop("Start out side of diagram", x, y, width, height);

      if (X < 0 || Y < 0)
        stop("Finish out side of diagram", X, Y);

      if (X >= width || Y >= height)
        stop("Finish out side of diagram", X, Y, width, height);

      if (x % 4 > 0 || y % 4 > 0)
        stop("Start not on a via", x, y);

      if (X % 4 > 0 || Y % 4 > 0)
        stop("Finish not on a via", X, Y);

      for   (int i = 0; i < width;  ++i)                                        // Clear the searched space
        for (int j = 0; j < height; ++j)
          d[i][j] = 0;

      for  (int i = -2; i <= 2; ++i)                                            // Add metal around via
       {for(int j = -2; j <= 2; ++j)
         {setIx(x+i, y, true); setIx(X+i, Y, true);
          setIy(x, y+j, true); setIy(X, Y+j, true);
         }
       }

      findShortestPath();                                                       // Shortest path

      for  (int i = -2; i <= 2; ++i)                                            // Remove metal around via
       {for(int j = -2; j <= 2; ++j)
         {setIx(x+i, y, false); setIx(X+i, Y, false);
          setIy(x, y+j, false); setIy(X, Y+j, false);
         }
       }

      if (found)                                                                // The found path will be from finish to start so we reverse it and remove the pixels used from further consideration.
       {final Stack<Pixel> r = new Stack<>();
        Pixel p = path.pop(); r.push(p);                                        // Start point

        for(int i = 0; i < 999999 && path.size() > 0; ++i)                      // Reverse along path
         {final Pixel q = path.pop();                                           // Current pixel
          final boolean[][]ixy = p.x != q.x ? level.ix : level.iy;              // Crossbar we used to reach the current pixel
          ixy[p.x][p.y] = false;                                                // Remove pixel from crossbar
          r.push(p = q);                                                        // Save pixel in path running from start to finish instead of from finish to start
         }
        path = r;
       }
     }
   }

  class Wire                                                                    // A wired connection on the diagram
   {final Pixel       start;                                                    // Start pixel
    final Pixel      finish;                                                    // End pixel
    final Stack<Pixel> path;                                                    // Path from start to finish
    final int         level;                                                    // The 1 - based  index of the level in the diagram
    final int         turns;                                                    // Number of turns along path
    final boolean     placed;                                                   // Whether the wire was place on the diagram or not

    Wire(int x, int y, int X, int Y)                                            // Create a wire and place it
     {start = new Pixel(x, y); finish = new Pixel(X, Y);
      Search S = null;
      for (Level l : levels)                                                    // Search each existing level for a placement
       {Search s = new Search(l, start, finish);                                // Search
        if(s.found) {S = s; break;}                                             // Found a level on which we can connect this wire
       }
      if (S == null)                                                            // Create a new level on which we are bound to succeed of thre is no room on any existing level
       {final Level  l = new Level();
        S = new Search(l, start, finish);                                       // Search
       }

      placed = S.found;                                                         // Save details of shortest path
      path   = S.path;
      turns  = S.turns != null ? S.turns : -1;
      wires.push(this);
      level  = 1 + levels.indexOf(S.level);                                     // Levels are based from 1
     }
   }

  public static void main(String[] args)                                        // Process a file containing a list if wires to be placed and write out the corresponding diagram
   {final int Width  = S.nextInt();
    final int Height = S.nextInt();
    final Diagram d  = new Diagram(Width, Height);
    final int wires  = S.nextInt();
    for (int i = 0; i < wires; i++)                                             // Process each wire
     {final int sx = S.nextInt(), sy = S.nextInt(),
                fx = S.nextInt(), fy = S.nextInt();
      final Wire w = d.new Wire(sx, sy, fx, fy);
      out("["+w.level+", "+w.path+"]");
     }
   }

  static void say(Object...O)                                                   // Say an error
   {final StringBuilder b = new StringBuilder();
    for (Object o: O) {b.append(" "); b.append(o);}
    System.err.println((O.length > 0 ? b.substring(1) : ""));
   }
  static void out(Object...O)                                                   // Output a result
   {final StringBuilder b = new StringBuilder();
    for (Object o: O) {b.append(" "); b.append(o);}
    System.out.println((O.length > 0 ? b.substring(1) : ""));
   }
  static void stop(Object...O)                                                  // Stop after writing an error message
   {say(O);
    new Exception().printStackTrace();
    System.exit(1);
   }
 }

//TEST 1
/*
16 16
3
0 4  4  4
0 8  4  8
0 0  4 12
----
[1, [[0,4], [1,4], [2,4], [3,4], [4,4]]]
[1, [[0,8], [1,8], [2,8], [3,8], [4,8]]]
[1, [[0,0], [1,0], [2,0], [2,1], [2,2], [2,3], [2,4], [2,5], [2,6], [2,7], [2,8], [2,9], [2,10], [2,11], [2,12], [3,12], [4,12]]]
*/

//TEST 2
/*
16 16
2
4  4   8  4
0  4  12  4
----
[1, [[4,4], [5,4], [6,4], [7,4], [8,4]]]
[1, [[0,4], [0,3], [0,2], [1,2], [2,2], [3,2], [4,2], [5,2], [6,2], [7,2], [8,2], [9,2], [10,2], [11,2], [12,2], [12,3], [12,4]]]
*/

//TEST 3
/*
16 16
1
0 0 4 0
----
[1, [[0,0], [1,0], [2,0], [3,0], [4,0]]]
*/
END
 }

#D1 Visualize                                                                   # Visualize a Silicon chip wiring diagrams

my sub wireHeader()                                                             #P Wire header
 {"   x,   y      X,   Y   L  Name    Path";
 }

sub printCode($%)                                                               # Print code to create a diagram
 {my ($d, %options) = @_;                                                       # Drawing, options
  my @t;
  push @t, sprintf "Silicon::Chip::Wiring::new(width=>%d, height=>%d);", $d->width//0, $d->height;
  for my $w($d->wires->@*)
   {my ($x, $y, $X, $Y) = @$w{qw(x y X Y)};
    push @t, sprintf "\$d->wire(%4d, %4d, %4d, %4d);", $x, $y, $X, $Y;
   }
  join "\n", @t, ''
 }

sub print($%)                                                                   # Print a diagram
 {my ($d, %options) = @_;                                                       # Drawing, options
  my @t; my $l = 0;
  push @t, wireHeader;
  for my $w($d->wires->@*)
   {push @t, $d->printWire($w);
    $l += $d->length($w);
   }
  unshift @t, "Length: $l";
  join "\n", @t, ''
 }

sub printInOrder($%)                                                            # Print a diagram
 {my ($d, %options) = @_;                                                       # Drawing, options
  my @t; my $l = 0;
  push @t, wireHeader;
  for my $w(
            sort {$a->x <=> $b->x}                                              # Sort wires into order
            sort {$a->y <=> $b->y}
            sort {$a->X <=> $b->X}
            sort {$a->Y <=> $b->Y}
            $d->wires->@*)
   {push @t, $d->printWire($w);
    $l += $d->length($w);
   }
  unshift @t, "Length: $l";
  join "\n", @t, ''
 }

sub printWire($$)                                                               # Print a wire to a string
 {my ($D, $W) = @_;                                                             # Drawing, wire
  my ($x, $y, $X, $Y, $l, $n, $p) = @$W{qw(x y X Y l n p)};
  sprintf "%4d,%4d   %4d,%4d  %2d  %-8s".(join '  ', map{join ',', @$_} @$p), $x, $y, $X, $Y, $l, $n
 }

sub printPath($)                                                                # Print a path as a two dimensional character image
 {my ($P) = @_;                                                                 # Path

  my $X; my $Y;
  for my $p(@$P)                                                                # Find dimensions of path
   {my ($x, $y, $s) = @$p;
    $X = maximum($X, $x); $Y = maximum($Y, $y);
   }

  my @s = ('.' x (1+$X)) x (1+$Y);                                              # Empty image

  for my $p(@$P)                                                                # Along the path
   {my ($x, $y, $s) = @$p;
    substr($s[$y], $x, 1) = $s//'.';
   }
  substr($s[$$P[ 0][1]], $$P[ 0][0], 1) = 'S';                                  # Finish
  substr($s[$$P[-1][1]], $$P[-1][0], 1) = 'F';                                  # Finish
  join "\n", @s, '';
 }

sub printHash($)                                                                #P Print a two dimensional hash
 {my ($x) = @_;                                                                 # Two dimensional hash
  my %x = $x->%*;

  my $w = 0; my $h = 0;
  for   my $x(sort keys %x)                                                     # Size of image
   {for my $y(sort keys $x{$x}->%*)
     {$w = maximum($w, $x);
      $h = maximum($h, $y);
     }
   }

  my @s = (' ' x (4+$w)) x (4+$h);                                              # Empty image
  for   my $x(sort keys %x)                                                     # Load image
   {for my $y(sort keys $x{$x}->%*)
     {substr($s[$y], $x, 1) = substr("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ", $x{$x}{$y} % 30, 1);
     }
   }
  my $s = join "\n", @s, '';
  $s =~ s(\s+\n) (\n)gs;
  $s                                                                            # Image as lines
 }

my sub printOverlays($$)                                                        # Print two overlaid two dimensional hash
 {my ($x, $y) = @_;                                                             # Two dimensional hashes
  my %x = $x->%*; my %y = $y->%*;

  my $w; my $h;
  for   my $x(sort keys %x)                                                     # Size of image
   {for my $y(sort keys $x{$x}->%*)
     {$w = maximum($w, $x);
      $h = maximum($h, $y);
     }
   }

  my @s = (' ' x (4+$w)) x (4+$h);                                              # Empty image
  for   my $x(sort keys %x)
   {for my $y(sort keys $x{$x}->%*)
     {substr($s[$y], $x, 1) = 1;
     }
   }

  for   my $x(sort keys %y)
   {for my $y(sort keys $y{$x}->%*)
     {substr($s[$y], $x, 1) = substr($s[$y], $x, 1) eq ' ' ? '2' : '3';
     }
   }
  my $s = join "\n", @s, '';
  $s =~ s(\s+\n) (\n)gs;
  $s
 }

sub printCells($$)                                                              #P Print the cells and sub cells in a diagram
 {my ($diagram, $level) = @_;                                                   # Diagram

  printOverlays($diagram->levelX->{$level}, $diagram->levelY->{$level});
 }

sub svg($%)                                                                     # Draw the bus lines by level.
 {my ($D, %options) = @_;                                                       # Wiring diagram, options

  if (defined(my $l = $options{level}))                                         # Draw the specified level
   {$D->svgLevel($l, %options);
   }
  else                                                                          # Draw all levels
   {my $L = $D->levels;
    my @s;
    for my $l(1..$L)
     {push @s, $D->svgLevel($l, %options);                                      # Write each level into a separate file
     }
    @s
   }
 }

my sub darkSvgColor                                                             # Generate a random dark color in hexadecimal format
 {my $c = int rand 3;
  my @r = map {int rand 128} 1..3;
  $r[$c] *= 2;

  sprintf "#%02X%02X%02X", @r;
 }

my sub collapsePath($)                                                          # Collapse a path to reduce the number of svg commands and thus the size of the svg files
 {my ($p) = @_;                                                                 # Path to collapse
           # Start   # Finish  # Direction
  my @c = [$$p[0],   $$p[0],   0];                                              # Collapse the path to reduce the number of svg commands.
  for my $i(1..$#$p)                                                            # Index path
   {my @q = $$p[$i]->@*;                                                        # Current element of path
    my @o = $c[-1][0]->@*;                                                      # Start of previous extension
    if ($o[0] != $q[0] and $o[1] != $q[1])                                      # New direction
     {push @c, [[@q], [@q]];
     }
    else
     {$c[-1][1] = [@q];
     }
   }

  if (@c == 1) {$c[0][2] = $c[0][0][2]}                                         # Straight line so direction is the same as the step away from the via
  else                                                                          # At least three segments
   {for my $i(1..@c-2)                                                          # Index path
     {$c[$i][2] = $c[$i][0][0] != $c[$i][1][0]? 0 : 1;                          # Direction of change
     }
    $c[ 0][2] = $c[1][2];                                                       # Step from first via is the same as first cross bar
    $c[-1][2] = $c[-2][2];                                                      # Step to last    via is the same as last  cross bar
   }

  @c                                                                            # Collapsed path [[start x, start y], [finish x, finish y], level]
 }

sub svgLevel($$%)                                                               #P Draw the bus lines by level.
 {my ($D, $level, %options) = @_;                                               # Wiring diagram, level, options

  my @defaults = (defaults=>                                                    # Default values
   {stroke_width => 0.5,
    opacity      => 0.75,
    stroke       => "transparent",
    fill         => "transparent",
   });

  my $svg = Svg::Simple::new(@defaults, %options, grid=>debugMask ? 1 : 0);     # Draw each wire via Svg. Grid set to 1 produces a grid that can be helpful debugging layout problems

  for my $w($D->wires->@*)                                                      # Each wire in X
   {my ($l, $p) = @$w{qw(l p)};                                                 # Level and path
    next unless defined($l) and $l == $level;                                   # Draw the specified level
    my @c = collapsePath($p);                                                   # Collapse the path to reduce the number of svg commands
    my $C = darkSvgColor;                                                       # Dark color
    for my $i(keys @c)                                                          # Index collapsed path
     {my $q = $c[$i];                                                           # Element of path
      my ($c, $d) = @$q;                                                        # Coordinates, dimensions
      my ($x, $y) = @$c;                                                        # Coordinates at start
      my ($X, $Y) = @$d;                                                        # Coordinates at end
      $x < $X ? $X++ : ++$x;
      $y < $Y ? $Y++ : ++$y;
      $x /= 4; $y /= 4; $X /= 4; $Y /= 4;                                       # Scale
      $svg->path(d=>"M $x $y L $X $y L $X $Y L $x $Y Z", fill=>$C);             # Rectangle as a path matching the gds2 implementation
      if ($i > 0 and $c[$i][2] != $c[$i-1][2])                                  # Change of level due to change of direction
       {my ($x, $y) = $c[$i-1][1]->@*;                                          # Coordinates of end of previous section
        my ($cx, $cy) = (($x+1/3)/4, ($y+1/3)/4);                               # Start of last sub cell of previous segment
        my ($dx, $dy) = (($x+2/3)/4, ($y+2/3)/4);                               # Far edge of last sub cell of previous segment
        $svg->path(d=>"M $cx $cy L $dx $cy L $dx $dy L $cx $dy Z", stroke=>"black", stroke_width=>1/48); # Show change of level
       }
     }
     my sub cd($$)                                                              # Coordinates of a start or end point
      {my ($i, $j) = @_;                                                        # Index for point, coordinate in point
       $$p[$i][$j] / 4
      }
     $svg->rect(x=>cd( 0, 0), y=>cd( 0, 1), width=>1/4, height=>1/4, fill=>"darkGreen");  # Draw start of wire
     $svg->rect(x=>cd(-1, 0), y=>cd(-1, 1), width=>1/4, height=>1/4, fill=>"darkRed");    # Draw end   of wire
   }

  my $t = $svg->print(width=>$D->width+1, height=>$D->height+1);                # Text of svg

  if (my $f = $options{svg})                                                    # Optionally write to an svg file
   {my $F = fpe q(svg), "${f}_$level", q(svg);                                  # Write each level into a separate file
    confess "Wiring file already exists: $F\n" if -e $F;
    owf($F, $t)
   }

  $t
 }

sub gds2($%)                                                                    # Draw the wires using GDS2
 {my ($diagram, %options) = @_;                                                 # Wiring diagram, output file, options
  my $gdsBlock  = $options{block};                                              # Existing GDS2 block
  my $gdsOut    = $options{svg};                                                # Write a newly created gds2 block to this file in the gds sub folder
  my $delta     = 1/4;                                                          # Offset from edge of each gate cell
  my $wireWidth = 1/4;                                                          # Width of a wire

  my $g = sub                                                                   # Draw as Graphics Design System 2 either inside an existing gds file or create a new one
   {return $gdsBlock if defined $gdsBlock;                                      # Drawing in an existing block
    createEmptyFile(my $f = fpe q(gds), $gdsOut, q(gds));                       # Make gds folder
    my $g = new GDS2(-fileName=>">$f");                                         # Draw as Graphics Design System 2
    $g->printInitLib(-name=>$gdsOut);
    $g->printBgnstr (-name=>$gdsOut);
    $g
   }->();

  my $s  = $wireWidth/2;                                                        # Half width of the wire
  my $t  = 1/2 + $s;                                                            # Center of wire
  my $S  = $wireWidth; # 2 * $s                                                 # Width of wire
  my @w  = $diagram->wires->@*;                                                 # Wires
  my $Nl = 4;                                                                   # Wiring layers within each level

  my $levels = $diagram->levels;                                                # Levels
  my $width  = $diagram->width;                                                 # Width
  my $height = $diagram->height;                                                # Height

  for my $wl(1..$levels)                                                        # Vias
   {for my $l(0..$Nl-1)                                                         # Insulation, x layer, insulation, y layer
     {for   my $x(0..$width)                                                    # Gate io pins run vertically along the "vias"
       {for my $y(0..$height)
         {my $x1 = $x; my $y1 = $y;
          my $x2 = $x1 + $wireWidth; my $y2 = $y1 + $wireWidth;
          $g->printBoundary(-layer=>$wl*$Nl+$l, -xy=>[$x1,$y1, $x2,$y1, $x2,$y2, $x1,$y2]); # Via
         }
       }
     }
   }

  for my $x(0..$width)                                                          # Number cells
   {$g->printText(-xy=>[$x, -1/8], -string=>"$x", -font=>3);                    # X coordinate
   }

  for my $y(1..$height)                                                         # Number cells
   {$g->printText(-xy=>[0, $y+$wireWidth*1.2], -string=>"$y", -font=>3);        # Y coordinate
   }

  my sub via($$$)                                                               # Draw a vertical connector. The vertical connectors are known as vias and transmit the gate inputs and outputs to the various wiring layers.
   {my ($x, $y, $l) = @_;                                                       # Options
    $g->printBoundary(-layer=>$l*$Nl+2, -xy=>[$x-$s,$y-$s, $x+$s,$y-$s, $x+$s,$y+$s, $x-$s,$y+$s]); # Vertical connector
   }

  #say STDERR wireHeader;
  for my $j(keys @w)                                                            # Layout each wire
   {my $w = $w[$j];
    my ($l, $p) = @$w{qw(l p)};
    my @c = collapsePath($p);                                                   # Collapse the path

    for my $i(keys @c)                                                          # Index collapsed path
     {my $q = $c[$i];                                                           # Element of path
      my ($c, $d) = @$q;                                                        # Coordinates, dimensions
      my ($x, $y) = @$c;                                                        # Coordinates at start
      my ($X, $Y) = @$d;                                                        # Coordinates at end
      $x < $X ? $X++ : ++$x;
      $y < $Y ? $Y++ : ++$y;
      $x /= 4; $y /= 4; $X /= 4; $Y /= 4;                                       # Scale

      my $L = $l * $Nl + ($$q[2] ? 2 : 0);                                      # Sub level in wiring level
      my $I = $l * $Nl + 1;                                                     # The insulation layer between the x and y crossbars.  We connect the x cross bars to the y cross bars through this later everytime we change direction in a wiring level.

      $g->printBoundary(-layer=>$L, -xy=>[$x,$y, $X,$y, $X,$Y, $x,$Y]);         # Fill in cell
      if ($i > 0 and $c[$i][2] != $c[$i-1][2])                                  # Change of level
       {$g->printBoundary(-layer=>$I, -xy=>[$X,$Y, $X-1/4,$Y, $X-1/4,$Y-1/4, $X,$Y-1/4]); # Step though insulation layer to connect the X crossbar to the Y crossbar.
       }
      $g->printText(-xy=>[$x+1/8, $y+1/8], -string=>($j+1).".$i");              # Y coordinate
     }
   }

  if (!defined($gdsBlock))                                                      # Close the library if a new ine is being defined
   {$g->printEndstr;
    $g->printEndlib;
   }
 }

#D0
#-------------------------------------------------------------------------------
# Export
#-------------------------------------------------------------------------------

use Exporter qw(import);

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

# containingFolder

@ISA          = qw(Exporter);
@EXPORT       = qw();
@EXPORT_OK    = qw();
%EXPORT_TAGS = (all=>[@EXPORT, @EXPORT_OK]);

#svg https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/svg/

=pod

=encoding utf-8

=for html <p><a href="https://github.com/philiprbrenan/SiliconChipWiring"><img src="https://github.com/philiprbrenan/SiliconChipWiring/workflows/Test/badge.svg"></a>

=head1 Name

Silicon::Chip::Wiring - Wire up a L<silicon|https://en.wikipedia.org/wiki/Silicon> L<chip|https://en.wikipedia.org/wiki/Integrated_circuit> to combine L<logic gates|https://en.wikipedia.org/wiki/Logic_gate> to transform software into hardware.

file:///home/phil/perl/cpan/SiliconChipWiring/lib/Silicon/Chip/svg/xy2_1.svg

=head1 Synopsis

=head2 Wire up a silicon chip

=for html <p><img src="https://raw.githubusercontent.com/philiprbrenan/SiliconChipWiring/main/lib/Silicon/Chip/svg/xy2_1.svg">


=head2 Assumptions

The gates are on the bottom layer if the chip.  Above the gates layer there as
many wiring levels as are needed to connect the gates. Vertical vias run from
the pins of the gates to each layer, so each vertical via can connect to an
input pin or an output pin of a gate.  On each level some of the vias (hence
gate pins) are connected together by L shaped strips of metal conductor running
along X and Y. The Y strips can cross over the X strips.  Each gate input pin
is connect to no more than one gate output pin.  Each gate output pin is
connected to no more than one gate input pin.  L<Silicon::Chip> automatically
inserts fan outs to enforce this rule. The fan outs look like sea shells on the
gate layout diagrams.

=head1 Description

Wire up a L<silicon|https://en.wikipedia.org/wiki/Silicon> L<chip|https://en.wikipedia.org/wiki/Integrated_circuit> to combine L<logic gates|https://en.wikipedia.org/wiki/Logic_gate> to transform software into hardware.


Version 20240331.


The following sections describe the methods in each functional area of this
module.  For an alphabetic listing of all methods by name see L<Index|/Index>.



=head1 Construct

Create a Silicon chip wiring diagram on one or more levels as necessary to make the connections requested.

=head2 new (%options)

New wiring diagram.

     Parameter  Description
  1  %options   Options

B<Example:>


  if (1)

   {my      $d = new(width=>4, height=>3, log=>1);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    my $a = $d->wire(0, 1, 2, 1, n=>'a');
            $d->layout;

    is_deeply(printPath($a->p), <<END);
  .........
  .........
  000000001
  1.......1
  S.......F
  END
   }

  if (1)

   {my        $d = new(width=>5, height=>5, log=>0);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    my $a =   $d->wire(0, 1, 2, 1, n=>'a');
    my $b =   $d->wire(1, 0, 1, 2, n=>'b');
    my $c =   $d->wire(2, 0, 2, 2, n=>'c');
    my $e =   $d->wire(0, 2, 1, 1, n=>'e');
    my $f =   $d->wire(0, 3, 4, 0, n=>'f');
    my $F =   $d->wire(1, 3, 3, 0, n=>'F');

              $d->layout;
    is_deeply($d->levels, 1);

    my $g =   $d->wire(0, 0, 3, 0, n=>'g');

              $d->layout;
    is_deeply($d->levels, 2);
    is_deeply($d->totalLength, 119);
    is_deeply($d->levels, 2);

    my $expected = <<END;
  Length: 119
     x,   y      X,   Y   L  Name    Path
     0,   0      3,   0   2  g       0,0,1  0,1,1  0,2,0  1,2,0  2,2,0  3,2,0  4,2,0  5,2,0  6,2,0  7,2,0  8,2,0  9,2,0  10,2,0  11,2,0  12,2,1  12,1,1  12,0
     0,   1      2,   1   1  a       0,4,1  0,3,1  0,2,0  1,2,0  2,2,0  3,2,0  4,2,0  5,2,0  6,2,0  7,2,0  8,2,1  8,3,1  8,4
     0,   2      1,   1   1  e       0,8,1  0,7,1  0,6,0  1,6,0  2,6,0  3,6,0  4,6,1  4,5,1  4,4
     0,   3      4,   0   1  f       0,12,1  0,11,1  0,10,0  1,10,0  2,10,0  3,10,0  4,10,0  5,10,0  6,10,0  7,10,0  8,10,0  9,10,0  10,10,0  11,10,0  12,10,0  13,10,0  14,10,1  14,9,1  14,8,1  14,7,1  14,6,1  14,5,1  14,4,1  14,3,1  14,2,1  14,1,1  14,0,0  15,0,0  16,0
     1,   0      1,   2   1  b       4,0,0  3,0,0  2,0,1  2,1,1  2,2,1  2,3,1  2,4,1  2,5,1  2,6,1  2,7,1  2,8,0  3,8,0  4,8
     1,   3      3,   0   1  F       4,12,1  4,13,1  4,14,0  5,14,0  6,14,0  7,14,0  8,14,0  9,14,0  10,14,1  10,13,1  10,12,1  10,11,1  10,10,1  10,9,1  10,8,1  10,7,1  10,6,1  10,5,1  10,4,1  10,3,1  10,2,1  10,1,1  10,0,0  11,0,0  12,0
     2,   0      2,   2   1  c       8,0,0  7,0,0  6,0,1  6,1,1  6,2,1  6,3,1  6,4,1  6,5,1  6,6,1  6,7,1  6,8,0  7,8,0  8,8
  END

    $d->layout;     is_deeply($d->printInOrder, $expected);

    is_deeply(printPath($a->p), <<END);
  .........
  .........
  000000001
  1.......1
  S.......F
  END

    is_deeply(printPath($b->p), <<END);
  ..10S
  ..1..
  ..1..
  ..1..
  ..1..
  ..1..
  ..1..
  ..1..
  ..00F
  END

    is_deeply(printPath($c->p), <<END);
  ......10S
  ......1..
  ......1..
  ......1..
  ......1..
  ......1..
  ......1..
  ......1..
  ......00F
  END

    is_deeply(printPath($e->p), <<END);
  .....
  .....
  .....
  .....
  ....F
  ....1
  00001
  1....
  S....
  END

    is_deeply(printPath($f->p), <<END);
  ..............00F
  ..............1..
  ..............1..
  ..............1..
  ..............1..
  ..............1..
  ..............1..
  ..............1..
  ..............1..
  ..............1..
  000000000000001..
  1................
  S................
  END

    is_deeply(printPath($F->p), <<END);
  ..........00F
  ..........1..
  ..........1..
  ..........1..
  ..........1..
  ..........1..
  ..........1..
  ..........1..
  ..........1..
  ..........1..
  ..........1..
  ..........1..
  ....S.....1..
  ....1.....1..
  ....0000001..
  END


    is_deeply(printPath($g->p), <<END);
  S...........F
  1...........1
  0000000000001
  END
    $d->layout;
    $d->svg (svg=>q(xy2), pngs=>2);
    $d->gds2(svg=>q/xy2/);
   }


=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/png/xy2.png">


=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/png/xy2_1.png">


=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/png/xy2_2.png">


=head2 wire($diagram, $x, $y, $X, $Y, %options)

New wire on a wiring diagram.

     Parameter  Description
  1  $diagram   Diagram
  2  $x         Start x
  3  $y         Start y
  4  $X         End x
  5  $Y         End y
  6  %options   Options

B<Example:>


  if (1)
   {my      $d = new(width=>4, height=>3, log=>1);

    my $a = $d->wire(0, 1, 2, 1, n=>'a');  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

            $d->layout;

    is_deeply(printPath($a->p), <<END);
  .........
  .........
  000000001
  1.......1
  S.......F
  END
   }

  if (1)
   {my        $d = new(width=>5, height=>5, log=>0);

    my $a =   $d->wire(0, 1, 2, 1, n=>'a');  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


    my $b =   $d->wire(1, 0, 1, 2, n=>'b');  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


    my $c =   $d->wire(2, 0, 2, 2, n=>'c');  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


    my $e =   $d->wire(0, 2, 1, 1, n=>'e');  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


    my $f =   $d->wire(0, 3, 4, 0, n=>'f');  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


    my $F =   $d->wire(1, 3, 3, 0, n=>'F');  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


              $d->layout;
    is_deeply($d->levels, 1);


    my $g =   $d->wire(0, 0, 3, 0, n=>'g');  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


              $d->layout;
    is_deeply($d->levels, 2);
    is_deeply($d->totalLength, 119);
    is_deeply($d->levels, 2);

    my $expected = <<END;
  Length: 119
     x,   y      X,   Y   L  Name    Path
     0,   0      3,   0   2  g       0,0,1  0,1,1  0,2,0  1,2,0  2,2,0  3,2,0  4,2,0  5,2,0  6,2,0  7,2,0  8,2,0  9,2,0  10,2,0  11,2,0  12,2,1  12,1,1  12,0
     0,   1      2,   1   1  a       0,4,1  0,3,1  0,2,0  1,2,0  2,2,0  3,2,0  4,2,0  5,2,0  6,2,0  7,2,0  8,2,1  8,3,1  8,4
     0,   2      1,   1   1  e       0,8,1  0,7,1  0,6,0  1,6,0  2,6,0  3,6,0  4,6,1  4,5,1  4,4
     0,   3      4,   0   1  f       0,12,1  0,11,1  0,10,0  1,10,0  2,10,0  3,10,0  4,10,0  5,10,0  6,10,0  7,10,0  8,10,0  9,10,0  10,10,0  11,10,0  12,10,0  13,10,0  14,10,1  14,9,1  14,8,1  14,7,1  14,6,1  14,5,1  14,4,1  14,3,1  14,2,1  14,1,1  14,0,0  15,0,0  16,0
     1,   0      1,   2   1  b       4,0,0  3,0,0  2,0,1  2,1,1  2,2,1  2,3,1  2,4,1  2,5,1  2,6,1  2,7,1  2,8,0  3,8,0  4,8
     1,   3      3,   0   1  F       4,12,1  4,13,1  4,14,0  5,14,0  6,14,0  7,14,0  8,14,0  9,14,0  10,14,1  10,13,1  10,12,1  10,11,1  10,10,1  10,9,1  10,8,1  10,7,1  10,6,1  10,5,1  10,4,1  10,3,1  10,2,1  10,1,1  10,0,0  11,0,0  12,0
     2,   0      2,   2   1  c       8,0,0  7,0,0  6,0,1  6,1,1  6,2,1  6,3,1  6,4,1  6,5,1  6,6,1  6,7,1  6,8,0  7,8,0  8,8
  END

    $d->layout;     is_deeply($d->printInOrder, $expected);

    is_deeply(printPath($a->p), <<END);
  .........
  .........
  000000001
  1.......1
  S.......F
  END

    is_deeply(printPath($b->p), <<END);
  ..10S
  ..1..
  ..1..
  ..1..
  ..1..
  ..1..
  ..1..
  ..1..
  ..00F
  END

    is_deeply(printPath($c->p), <<END);
  ......10S
  ......1..
  ......1..
  ......1..
  ......1..
  ......1..
  ......1..
  ......1..
  ......00F
  END

    is_deeply(printPath($e->p), <<END);
  .....
  .....
  .....
  .....
  ....F
  ....1
  00001
  1....
  S....
  END

    is_deeply(printPath($f->p), <<END);
  ..............00F
  ..............1..
  ..............1..
  ..............1..
  ..............1..
  ..............1..
  ..............1..
  ..............1..
  ..............1..
  ..............1..
  000000000000001..
  1................
  S................
  END

    is_deeply(printPath($F->p), <<END);
  ..........00F
  ..........1..
  ..........1..
  ..........1..
  ..........1..
  ..........1..
  ..........1..
  ..........1..
  ..........1..
  ..........1..
  ..........1..
  ..........1..
  ....S.....1..
  ....1.....1..
  ....0000001..
  END


    is_deeply(printPath($g->p), <<END);
  S...........F
  1...........1
  0000000000001
  END
    $d->layout;
    $d->svg (svg=>q(xy2), pngs=>2);
    $d->gds2(svg=>q/xy2/);
   }


=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/png/xy2.png">


=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/png/xy2_1.png">


=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/png/xy2_2.png">


=head2 layout  ($diagram, %options)

Layout the wires using Java

     Parameter  Description
  1  $diagram   Diagram
  2  %options   Options

=head2 numberOfWires   ($D, %options)

Number of wires in the diagram

     Parameter  Description
  1  $D         Diagram
  2  %options   Options

B<Example:>


  if (1)
   {my      $d = new(width=>3, height=>2);
    my $w = $d->wire(1, 1, 2, 1, n=>'a');
            $d->layout;

    is_deeply($d->numberOfWires, 1);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    is_deeply(printPath($w->p), <<END);
  .........
  .........
  .........
  .........
  ....S000F
  END
    $d->gds2(svg=>q(x1));
   }


=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/svg/x1.svg">


=head2 length  ($D, $w)

Length of a wire in a diagram

     Parameter  Description
  1  $D         Diagram
  2  $w         Wire

B<Example:>


  if (1)
   {my      $d = new(width=>2, height=>3);
    my $w = $d->wire(1, 1, 1, 2, n=>'b');
            $d->layout;

    is_deeply($d->length($w), 5);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    is_deeply(printPath($w->p), <<END);
  .....
  .....
  .....
  .....
  ....S
  ....1
  ....1
  ....1
  ....F
  END
    $d->svg (svg=>q(y1));
    $d->gds2(svg=>q(y1));
   }


=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/svg/y1.svg">


=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/svg/y1_1.svg">


=head2 totalLength ($d)

Total length of wires

     Parameter  Description
  1  $d         Diagram

B<Example:>


  if (1)
   {my      $d = new(width=>4, height=>3, log=>1);
    my $a = $d->wire(0, 1, 2, 1, n=>'a');
            $d->layout;

    is_deeply(printPath($a->p), <<END);
  .........
  .........
  000000001
  1.......1
  S.......F
  END
   }

  if (1)
   {my        $d = new(width=>5, height=>5, log=>0);
    my $a =   $d->wire(0, 1, 2, 1, n=>'a');
    my $b =   $d->wire(1, 0, 1, 2, n=>'b');
    my $c =   $d->wire(2, 0, 2, 2, n=>'c');
    my $e =   $d->wire(0, 2, 1, 1, n=>'e');
    my $f =   $d->wire(0, 3, 4, 0, n=>'f');
    my $F =   $d->wire(1, 3, 3, 0, n=>'F');

              $d->layout;
    is_deeply($d->levels, 1);

    my $g =   $d->wire(0, 0, 3, 0, n=>'g');

              $d->layout;
    is_deeply($d->levels, 2);

    is_deeply($d->totalLength, 119);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    is_deeply($d->levels, 2);

    my $expected = <<END;
  Length: 119
     x,   y      X,   Y   L  Name    Path
     0,   0      3,   0   2  g       0,0,1  0,1,1  0,2,0  1,2,0  2,2,0  3,2,0  4,2,0  5,2,0  6,2,0  7,2,0  8,2,0  9,2,0  10,2,0  11,2,0  12,2,1  12,1,1  12,0
     0,   1      2,   1   1  a       0,4,1  0,3,1  0,2,0  1,2,0  2,2,0  3,2,0  4,2,0  5,2,0  6,2,0  7,2,0  8,2,1  8,3,1  8,4
     0,   2      1,   1   1  e       0,8,1  0,7,1  0,6,0  1,6,0  2,6,0  3,6,0  4,6,1  4,5,1  4,4
     0,   3      4,   0   1  f       0,12,1  0,11,1  0,10,0  1,10,0  2,10,0  3,10,0  4,10,0  5,10,0  6,10,0  7,10,0  8,10,0  9,10,0  10,10,0  11,10,0  12,10,0  13,10,0  14,10,1  14,9,1  14,8,1  14,7,1  14,6,1  14,5,1  14,4,1  14,3,1  14,2,1  14,1,1  14,0,0  15,0,0  16,0
     1,   0      1,   2   1  b       4,0,0  3,0,0  2,0,1  2,1,1  2,2,1  2,3,1  2,4,1  2,5,1  2,6,1  2,7,1  2,8,0  3,8,0  4,8
     1,   3      3,   0   1  F       4,12,1  4,13,1  4,14,0  5,14,0  6,14,0  7,14,0  8,14,0  9,14,0  10,14,1  10,13,1  10,12,1  10,11,1  10,10,1  10,9,1  10,8,1  10,7,1  10,6,1  10,5,1  10,4,1  10,3,1  10,2,1  10,1,1  10,0,0  11,0,0  12,0
     2,   0      2,   2   1  c       8,0,0  7,0,0  6,0,1  6,1,1  6,2,1  6,3,1  6,4,1  6,5,1  6,6,1  6,7,1  6,8,0  7,8,0  8,8
  END

    $d->layout;     is_deeply($d->printInOrder, $expected);

    is_deeply(printPath($a->p), <<END);
  .........
  .........
  000000001
  1.......1
  S.......F
  END

    is_deeply(printPath($b->p), <<END);
  ..10S
  ..1..
  ..1..
  ..1..
  ..1..
  ..1..
  ..1..
  ..1..
  ..00F
  END

    is_deeply(printPath($c->p), <<END);
  ......10S
  ......1..
  ......1..
  ......1..
  ......1..
  ......1..
  ......1..
  ......1..
  ......00F
  END

    is_deeply(printPath($e->p), <<END);
  .....
  .....
  .....
  .....
  ....F
  ....1
  00001
  1....
  S....
  END

    is_deeply(printPath($f->p), <<END);
  ..............00F
  ..............1..
  ..............1..
  ..............1..
  ..............1..
  ..............1..
  ..............1..
  ..............1..
  ..............1..
  ..............1..
  000000000000001..
  1................
  S................
  END

    is_deeply(printPath($F->p), <<END);
  ..........00F
  ..........1..
  ..........1..
  ..........1..
  ..........1..
  ..........1..
  ..........1..
  ..........1..
  ..........1..
  ..........1..
  ..........1..
  ..........1..
  ....S.....1..
  ....1.....1..
  ....0000001..
  END


    is_deeply(printPath($g->p), <<END);
  S...........F
  1...........1
  0000000000001
  END
    $d->layout;
    $d->svg (svg=>q(xy2), pngs=>2);
    $d->gds2(svg=>q/xy2/);
   }


=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/png/xy2.png">


=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/png/xy2_1.png">


=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/png/xy2_2.png">


=head1 Shortest Path

Find the shortest path using compiled code

=head1 Visualize

Visualize a Silicon chip wiring diagrams

=head2 printCode   ($d, %options)

Print code to create a diagram

     Parameter  Description
  1  $d         Drawing
  2  %options   Options

B<Example:>


  if (1)
   {my      $d = new(width=>3, height=>3);
    my $a = $d->wire(1, 1, 2, 1, n=>'a');
    my $b = $d->wire(1, 2, 2, 2, n=>'b');
            $d->layout;
    is_deeply($d->print, <<END);
  Length: 10
     x,   y      X,   Y   L  Name    Path
     1,   1      2,   1   1  a       4,4,0  5,4,0  6,4,0  7,4,0  8,4
     1,   2      2,   2   1  b       4,8,0  5,8,0  6,8,0  7,8,0  8,8
  END
    is_deeply($d->printWire($a), "   1,   1      2,   1   1  a       4,4,0  5,4,0  6,4,0  7,4,0  8,4");

    is_deeply($d->printCode, <<END);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

  Silicon::Chip::Wiring::new(width=>3, height=>3);
  \$d->wire(   1,    1,    2,    1);
  \$d->wire(   1,    2,    2,    2);
  END
    is_deeply($d->printInOrder, <<END);
  Length: 10
     x,   y      X,   Y   L  Name    Path
     1,   1      2,   1   1  a       4,4,0  5,4,0  6,4,0  7,4,0  8,4
     1,   2      2,   2   1  b       4,8,0  5,8,0  6,8,0  7,8,0  8,8
  END
   }


=head2 print   ($d, %options)

Print a diagram

     Parameter  Description
  1  $d         Drawing
  2  %options   Options

B<Example:>


  if (1)
   {my      $d = new(width=>3, height=>3);
    my $a = $d->wire(1, 1, 2, 1, n=>'a');
    my $b = $d->wire(1, 2, 2, 2, n=>'b');
            $d->layout;

    is_deeply($d->print, <<END);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

  Length: 10
     x,   y      X,   Y   L  Name    Path
     1,   1      2,   1   1  a       4,4,0  5,4,0  6,4,0  7,4,0  8,4
     1,   2      2,   2   1  b       4,8,0  5,8,0  6,8,0  7,8,0  8,8
  END
    is_deeply($d->printWire($a), "   1,   1      2,   1   1  a       4,4,0  5,4,0  6,4,0  7,4,0  8,4");
    is_deeply($d->printCode, <<END);
  Silicon::Chip::Wiring::new(width=>3, height=>3);
  \$d->wire(   1,    1,    2,    1);
  \$d->wire(   1,    2,    2,    2);
  END
    is_deeply($d->printInOrder, <<END);
  Length: 10
     x,   y      X,   Y   L  Name    Path
     1,   1      2,   1   1  a       4,4,0  5,4,0  6,4,0  7,4,0  8,4
     1,   2      2,   2   1  b       4,8,0  5,8,0  6,8,0  7,8,0  8,8
  END
   }


=head2 printInOrder($d, %options)

Print a diagram

     Parameter  Description
  1  $d         Drawing
  2  %options   Options

B<Example:>


  if (1)
   {my      $d = new(width=>3, height=>3);
    my $a = $d->wire(1, 1, 2, 1, n=>'a');
    my $b = $d->wire(1, 2, 2, 2, n=>'b');
            $d->layout;
    is_deeply($d->print, <<END);
  Length: 10
     x,   y      X,   Y   L  Name    Path
     1,   1      2,   1   1  a       4,4,0  5,4,0  6,4,0  7,4,0  8,4
     1,   2      2,   2   1  b       4,8,0  5,8,0  6,8,0  7,8,0  8,8
  END
    is_deeply($d->printWire($a), "   1,   1      2,   1   1  a       4,4,0  5,4,0  6,4,0  7,4,0  8,4");
    is_deeply($d->printCode, <<END);
  Silicon::Chip::Wiring::new(width=>3, height=>3);
  \$d->wire(   1,    1,    2,    1);
  \$d->wire(   1,    2,    2,    2);
  END

    is_deeply($d->printInOrder, <<END);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

  Length: 10
     x,   y      X,   Y   L  Name    Path
     1,   1      2,   1   1  a       4,4,0  5,4,0  6,4,0  7,4,0  8,4
     1,   2      2,   2   1  b       4,8,0  5,8,0  6,8,0  7,8,0  8,8
  END
   }


=head2 printWire   ($D, $W)

Print a wire to a string

     Parameter  Description
  1  $D         Drawing
  2  $W         Wire

B<Example:>


  if (1)
   {my      $d = new(width=>3, height=>3);
    my $a = $d->wire(1, 1, 2, 1, n=>'a');
    my $b = $d->wire(1, 2, 2, 2, n=>'b');
            $d->layout;
    is_deeply($d->print, <<END);
  Length: 10
     x,   y      X,   Y   L  Name    Path
     1,   1      2,   1   1  a       4,4,0  5,4,0  6,4,0  7,4,0  8,4
     1,   2      2,   2   1  b       4,8,0  5,8,0  6,8,0  7,8,0  8,8
  END

    is_deeply($d->printWire($a), "   1,   1      2,   1   1  a       4,4,0  5,4,0  6,4,0  7,4,0  8,4");  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

    is_deeply($d->printCode, <<END);
  Silicon::Chip::Wiring::new(width=>3, height=>3);
  \$d->wire(   1,    1,    2,    1);
  \$d->wire(   1,    2,    2,    2);
  END
    is_deeply($d->printInOrder, <<END);
  Length: 10
     x,   y      X,   Y   L  Name    Path
     1,   1      2,   1   1  a       4,4,0  5,4,0  6,4,0  7,4,0  8,4
     1,   2      2,   2   1  b       4,8,0  5,8,0  6,8,0  7,8,0  8,8
  END
   }


=head2 printPath   ($P)

Print a path as a two dimensional character image

     Parameter  Description
  1  $P         Path

B<Example:>


  if (1)
   {my      $d = new(width=>3, height=>3);
    my $a = $d->wire(1, 1, 2, 2, n=>'a');
            $d->layout;

    is_deeply(printPath($a->p), <<END);  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

  .........
  .........
  .........
  .........
  ....S01..
  ......1..
  ......1..
  ......1..
  ......00F
  END
    $d->gds2(svg=>q(xy1));
    $d->svg (svg=>q(xy1));
   }


=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/svg/xy1.svg">


=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/svg/xy1_1.svg">


=head2 svg ($D, %options)

Draw the bus lines by level.

     Parameter  Description
  1  $D         Wiring diagram
  2  %options   Options

B<Example:>


  if (1)
   {my      $d = new(width=>2, height=>3);
    my $w = $d->wire(1, 1, 1, 2, n=>'b');
            $d->layout;
    is_deeply($d->length($w), 5);
    is_deeply(printPath($w->p), <<END);
  .....
  .....
  .....
  .....
  ....S
  ....1
  ....1
  ....1
  ....F
  END

    $d->svg (svg=>q(y1));  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲


    $d->gds2(svg=>q(y1));  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

   }


=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/svg/y1.svg">


=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/svg/y1_1.svg">


=head2 gds2($diagram, %options)

Draw the wires using GDS2

     Parameter  Description
  1  $diagram   Wiring diagram
  2  %options   Output file

B<Example:>


  if (1)
   {my      $d = new(width=>2, height=>3);
    my $w = $d->wire(1, 1, 1, 2, n=>'b');
            $d->layout;
    is_deeply($d->length($w), 5);
    is_deeply(printPath($w->p), <<END);
  .....
  .....
  .....
  .....
  ....S
  ....1
  ....1
  ....1
  ....F
  END
    $d->svg (svg=>q(y1));

    $d->gds2(svg=>q(y1));  # 𝗘𝘅𝗮𝗺𝗽𝗹𝗲

   }


=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/svg/y1.svg">


=for html <img src="https://vanina-andrea.s3.us-east-2.amazonaws.com/SiliconChipWiring/lib/Silicon/Chip/svg/y1_1.svg">



=head1 Hash Definitions




=head2 Silicon::Chip::Wiring Definition


Wire




=head3 Output fields


=head4 X

End   x position of wire

=head4 Y

End   y position of wire

=head4 height

Height of chip

=head4 l

Level on which wire is drawn

=head4 levelX

{level}{x}{y} - available cells in X  - used cells are deleted. Normally if present the cell, if present has a positive value.  If it has a negative it is a temporary addition for the purpose of connecting the end points of the wires to the vertical vias.

=head4 levelY

{level}{x}{y} - available cells in Y

=head4 levels

Levels in use

=head4 log

Log activity if true

=head4 n

Optional name

=head4 options

Creation options

=head4 p

Path from start to finish

=head4 width

Width of chip

=head4 wires

Wires on diagram

=head4 x

Start x position of wire

=head4 y

Start y position of wire



=head1 Private Methods

=head2 resetLevels ($diagram, %options)

Reset all the levels so we can layout again

     Parameter  Description
  1  $diagram   Diagram
  2  %options   Options

=head2 java()

Using Java as it is faster than Perl to layout the connections


=head2 printHash   ($x)

Print a two dimensional hash

     Parameter  Description
  1  $x         Two dimensional hash

=head2 printCells  ($diagram, $level)

Print the cells and sub cells in a diagram

     Parameter  Description
  1  $diagram   Diagram
  2  $level

=head2 svgLevel($D, $level, %options)

Draw the bus lines by level.

     Parameter  Description
  1  $D         Wiring diagram
  2  $level     Level
  3  %options   Options


=head1 Index


1 L<gds2|/gds2> - Draw the wires using GDS2

2 L<java|/java> - Using Java as it is faster than Perl to layout the connections

3 L<layout|/layout> - Layout the wires using Java

4 L<length|/length> - Length of a wire in a diagram

5 L<new|/new> - New wiring diagram.

6 L<numberOfWires|/numberOfWires> - Number of wires in the diagram

7 L<print|/print> - Print a diagram

8 L<printCells|/printCells> - Print the cells and sub cells in a diagram

9 L<printCode|/printCode> - Print code to create a diagram

10 L<printHash|/printHash> - Print a two dimensional hash

11 L<printInOrder|/printInOrder> - Print a diagram

12 L<printPath|/printPath> - Print a path as a two dimensional character image

13 L<printWire|/printWire> - Print a wire to a string

14 L<resetLevels|/resetLevels> - Reset all the levels so we can layout again

15 L<svg|/svg> - Draw the bus lines by level.

16 L<svgLevel|/svgLevel> - Draw the bus lines by level.

17 L<totalLength|/totalLength> - Total length of wires

18 L<wire|/wire> - New wire on a wiring diagram.

=head1 Installation

This module is written in 100% Pure Perl and, thus, it is easy to read,
comprehend, use, modify and install via B<cpan>:

  sudo cpan install Silicon::Chip::Wiring

=head1 Author

L<philiprbrenan@gmail.com|mailto:philiprbrenan@gmail.com>

L<http://prb.appaapps.com|http://prb.appaapps.com>

=head1 Copyright

Copyright (c) 2016-2023 Philip R Brenan.

This module is free software. It may be used, redistributed and/or modified
under the same terms as Perl itself.

=cut



goto finish if caller;
clearFolder(q(svg), 99);                                                        # Clear the output svg folder
clearFolder(q(gds), 99);                                                        # Clear the output gds folder
my $start = time;
eval "use Test::More";
eval "Test::More->builder->output('/dev/null')" unless $ENV{GITHUB_ACTIONS};
eval {goto latest}                              unless $ENV{GITHUB_ACTIONS};;

my sub  ok($)        {!$_[0] and confess; &ok( $_[0])}
my sub nok($)        {&ok(!$_[0])}

# Tests

#latest:;
if (1)                                                                          #
 {my      $d = new(width=>3, height=>2);
  is_deeply($d->height, 2);
  is_deeply($d->width,  3);
 }

#latest:;
if (1)                                                                          #TnumberOfWires
 {my      $d = new(width=>3, height=>2);
  my $w = $d->wire(1, 1, 2, 1, n=>'a');
          $d->layout;
  is_deeply($d->numberOfWires, 1);
  is_deeply(printPath($w->p), <<END);
.........
.........
.........
.........
....S000F
END
  $d->gds2(svg=>q(x1));
 }

#latest:;
if (1)                                                                          #Tsvg #Tgds2 #Tlength
 {my      $d = new(width=>2, height=>3);
  my $w = $d->wire(1, 1, 1, 2, n=>'b');
          $d->layout;
  is_deeply($d->length($w), 5);
  is_deeply(printPath($w->p), <<END);
.....
.....
.....
.....
....S
....1
....1
....1
....F
END
  $d->svg (svg=>q(y1));
  $d->gds2(svg=>q(y1));
 }

#latest:;
if (1)                                                                          #TprintPath
 {my      $d = new(width=>3, height=>3);
  my $a = $d->wire(1, 1, 2, 2, n=>'a');
          $d->layout;
  is_deeply(printPath($a->p), <<END);
.........
.........
.........
.........
....S01..
......1..
......1..
......1..
......00F
END
  $d->gds2(svg=>q(xy1));
  $d->svg (svg=>q(xy1));
 }

#latest:;
if (1)                                                                          #Tprint #TprintWire #TprintCode #TprintInOrder
 {my      $d = new(width=>3, height=>3);
  my $a = $d->wire(1, 1, 2, 1, n=>'a');
  my $b = $d->wire(1, 2, 2, 2, n=>'b');
          $d->layout;
  is_deeply($d->print, <<END);
Length: 10
   x,   y      X,   Y   L  Name    Path
   1,   1      2,   1   1  a       4,4,0  5,4,0  6,4,0  7,4,0  8,4
   1,   2      2,   2   1  b       4,8,0  5,8,0  6,8,0  7,8,0  8,8
END
  is_deeply($d->printWire($a), "   1,   1      2,   1   1  a       4,4,0  5,4,0  6,4,0  7,4,0  8,4");
  is_deeply($d->printCode, <<END);
Silicon::Chip::Wiring::new(width=>3, height=>3);
\$d->wire(   1,    1,    2,    1);
\$d->wire(   1,    2,    2,    2);
END
  is_deeply($d->printInOrder, <<END);
Length: 10
   x,   y      X,   Y   L  Name    Path
   1,   1      2,   1   1  a       4,4,0  5,4,0  6,4,0  7,4,0  8,4
   1,   2      2,   2   1  b       4,8,0  5,8,0  6,8,0  7,8,0  8,8
END
 }

#latest:;
if (1)                                                                          #Tnew #Twire #TtotalLength
 {my      $d = new(width=>4, height=>3, log=>1);
  my $a = $d->wire(0, 1, 2, 1, n=>'a');
          $d->layout;

  is_deeply(printPath($a->p), <<END);
.........
.........
000000001
1.......1
S.......F
END
 }

#latest:;
if (1)                                                                          #
 {my      $d = new(width=>4, height=>3, log=>1);
  my $b = $d->wire(1, 0, 1, 2, n=>'b');
          $d->layout;

  is_deeply(printPath($b->p), <<END);
..10S
..1..
..1..
..1..
..1..
..1..
..1..
..1..
..00F
END
 }

#latest:;
if (1)                                                                          #
 {my      $d = new(width=>4, height=>3, log=>1);
  my $c = $d->wire(2, 0, 2, 2, n=>'c');
          $d->layout;

  is_deeply(printPath($c->p), <<END);
......10S
......1..
......1..
......1..
......1..
......1..
......1..
......1..
......00F
END
 }

#latest:;
if (1)                                                                          #
 {my      $d = new(width=>4, height=>3, log=>1);
  my $e = $d->wire(0, 2, 1, 1, n=>'e');
          $d->layout;

  is_deeply(printPath($e->p), <<END);
.....
.....
.....
.....
..00F
..1..
..1..
..1..
S01..
END
 }

#latest:;
if (1)                                                                          #
 {my      $d = new(width=>5, height=>4, log=>1);
  my $f = $d->wire(0, 3, 4, 0, n=>'f');
          $d->layout;

  is_deeply(printPath($f->p), <<END);
..............00F
..............1..
..............1..
..............1..
..............1..
..............1..
..............1..
..............1..
..............1..
..............1..
000000000000001..
1................
S................
END
 }

#latest:;
if (1)                                                                          #
 {my      $d = new(width=>5, height=>4, log=>1);
  my $F = $d->wire(1, 3, 3, 0, n=>'F');
          $d->layout;

  is_deeply(printPath($F->p), <<END);
..........00F
..........1..
..........1..
..........1..
..........1..
..........1..
..........1..
..........1..
..........1..
..........1..
....0000001..
....1........
....S........
END
 }

#latest:;
if (1)                                                                          #Tlayout
 {my      $d = new(width=>4, height=>3, log=>1);
  my $g = $d->wire(0, 0, 3, 0, n=>'g');
          $d->layout;

  is_deeply(printPath($g->p), <<END);
S...........F
1...........1
0000000000001
END
 }

#latest:;
if (1)                                                                          #Tnew #Twire #TtotalLength
 {my        $d = new(width=>5, height=>5, log=>0);
  my $a =   $d->wire(0, 1, 2, 1, n=>'a');
  my $b =   $d->wire(1, 0, 1, 2, n=>'b');
  my $c =   $d->wire(2, 0, 2, 2, n=>'c');
  my $e =   $d->wire(0, 2, 1, 1, n=>'e');
  my $f =   $d->wire(0, 3, 4, 0, n=>'f');
  my $F =   $d->wire(1, 3, 3, 0, n=>'F');

            $d->layout;
  is_deeply($d->levels, 1);

  my $g =   $d->wire(0, 0, 3, 0, n=>'g');

            $d->layout;
  is_deeply($d->levels, 2);
  is_deeply($d->totalLength, 119);
  is_deeply($d->levels, 2);

  my $expected = <<END;
Length: 119
   x,   y      X,   Y   L  Name    Path
   0,   0      3,   0   2  g       0,0,1  0,1,1  0,2,0  1,2,0  2,2,0  3,2,0  4,2,0  5,2,0  6,2,0  7,2,0  8,2,0  9,2,0  10,2,0  11,2,0  12,2,1  12,1,1  12,0
   0,   1      2,   1   1  a       0,4,1  0,3,1  0,2,0  1,2,0  2,2,0  3,2,0  4,2,0  5,2,0  6,2,0  7,2,0  8,2,1  8,3,1  8,4
   0,   2      1,   1   1  e       0,8,1  0,7,1  0,6,0  1,6,0  2,6,0  3,6,0  4,6,1  4,5,1  4,4
   0,   3      4,   0   1  f       0,12,1  0,11,1  0,10,0  1,10,0  2,10,0  3,10,0  4,10,0  5,10,0  6,10,0  7,10,0  8,10,0  9,10,0  10,10,0  11,10,0  12,10,0  13,10,0  14,10,1  14,9,1  14,8,1  14,7,1  14,6,1  14,5,1  14,4,1  14,3,1  14,2,1  14,1,1  14,0,0  15,0,0  16,0
   1,   0      1,   2   1  b       4,0,0  3,0,0  2,0,1  2,1,1  2,2,1  2,3,1  2,4,1  2,5,1  2,6,1  2,7,1  2,8,0  3,8,0  4,8
   1,   3      3,   0   1  F       4,12,1  4,13,1  4,14,0  5,14,0  6,14,0  7,14,0  8,14,0  9,14,0  10,14,1  10,13,1  10,12,1  10,11,1  10,10,1  10,9,1  10,8,1  10,7,1  10,6,1  10,5,1  10,4,1  10,3,1  10,2,1  10,1,1  10,0,0  11,0,0  12,0
   2,   0      2,   2   1  c       8,0,0  7,0,0  6,0,1  6,1,1  6,2,1  6,3,1  6,4,1  6,5,1  6,6,1  6,7,1  6,8,0  7,8,0  8,8
END

  $d->layout;     is_deeply($d->printInOrder, $expected);

  is_deeply(printPath($a->p), <<END);
.........
.........
000000001
1.......1
S.......F
END

  is_deeply(printPath($b->p), <<END);
..10S
..1..
..1..
..1..
..1..
..1..
..1..
..1..
..00F
END

  is_deeply(printPath($c->p), <<END);
......10S
......1..
......1..
......1..
......1..
......1..
......1..
......1..
......00F
END

  is_deeply(printPath($e->p), <<END);
.....
.....
.....
.....
....F
....1
00001
1....
S....
END

  is_deeply(printPath($f->p), <<END);
..............00F
..............1..
..............1..
..............1..
..............1..
..............1..
..............1..
..............1..
..............1..
..............1..
000000000000001..
1................
S................
END

  is_deeply(printPath($F->p), <<END);
..........00F
..........1..
..........1..
..........1..
..........1..
..........1..
..........1..
..........1..
..........1..
..........1..
..........1..
..........1..
....S.....1..
....1.....1..
....0000001..
END


  is_deeply(printPath($g->p), <<END);
S...........F
1...........1
0000000000001
END
  $d->layout;
  $d->svg (svg=>q(xy2), pngs=>2);
  $d->gds2(svg=>q/xy2/);
 }

#    Original   Collapse
#    012345678  012345678
#  0
#  1
#  2 000000001  0.......1
#  3 1       1  .       .
#  4 1       1  0       1

#latest:;
if (1)                                                                          #TcollapsePath
 {my @p = collapsePath([
  [0, 4, 1],
  [0, 3, 1],
  [0, 2, 0],
  [1, 2, 0],
  [2, 2, 0],
  [3, 2, 0],
  [4, 2, 0],
  [5, 2, 0],
  [6, 2, 0],
  [7, 2, 0],
  [8, 2, 1],
  [8, 3, 1],
  [8, 4]]);
  is_deeply([@p], [
   [[0, 4, 1], [0, 2, 0], 0],
   [[1, 2, 0], [8, 2, 1], 0],
   [[8, 3, 1], [8, 4],    0]]);
 }

#latest:;
if (1)
 {my @p = collapsePath([
  [0, 12, 1],
  [0, 11, 1],
  [0, 10, 0],
  [1, 10, 0],
  [2, 10, 0],
  [3, 10, 0],
  [4, 10, 0],
  [5, 10, 0],
  [6, 10, 0],
  [7, 10, 0],
  [8, 10, 0],
  [9, 10, 0],
  [10, 10, 0],
  [11, 10, 0],
  [12, 10, 0],
  [13, 10, 0],
  [14, 10, 1],
  [14, 9, 1],
  [14, 8, 1],
  [14, 7, 1],
  [14, 6, 1],
  [14, 5, 1],
  [14, 4, 1],
  [14, 3, 1],
  [14, 2, 1],
  [14, 1, 1],
  [14, 0, 0],
  [15, 0, 0],
  [16, 0]]);
  is_deeply([@p], [
  [[0, 12, 1], [ 0, 10, 0], 0],
  [[1, 10, 0], [14, 10, 1], 0],
  [[14, 9, 1], [14,  0, 0], 1],
  [[15, 0, 0], [16,  0],    1],
   ]);
 }

#latest:;
if (1)                                                                          #
 {my $d = new(width=>90, height=>20);
     $d->wire( 9, 14, 50,  5);
     $d->wire(13,  5, 50, 12);
     $d->wire(13,  8, 54,  5);
     $d->wire( 5, 11, 42,  5);
     $d->wire( 9,  2, 42, 12);
     $d->wire(13,  2, 50,  7);
     $d->wire(13, 11, 54, 10);
     $d->wire(13, 14, 54, 15);
     $d->wire( 5, 14, 42, 10);
     $d->wire(17,  2, 58,  2);
     $d->wire( 9,  8, 46,  7);
     $d->wire( 9, 11, 46, 12);
     $d->wire( 5,  8, 38, 12);
     $d->wire( 9,  5, 46,  5);
     $d->wire( 5,  5, 38,  7);
     $d->wire( 5,  2, 38,  2);
     $d->wire(37,  7, 58,  4);
     $d->wire(41,  7, 62,  4);
     $d->wire(33,  9, 50,  3);
     $d->wire(41, 12, 62, 10);
     $d->wire(45,  2, 62,  8);
     $d->wire(33, 14, 50,  9);
     $d->wire(45,  7, 62, 12);
     $d->wire(37,  4, 54,  8);
     $d->wire(37,  9, 54, 13);
     $d->wire(41,  2, 62,  2);
     $d->wire(33,  2, 46,  9);
     $d->wire(33,  7, 46, 14);
     $d->wire(49,  7, 66,  4);
     $d->wire(33, 12, 50, 14);
     $d->wire(45, 12, 62, 14);
     $d->wire(49, 12, 66, 10);
     $d->wire(53,  2, 66,  8);
     $d->wire(37,  2, 54,  3);
     $d->wire(53,  7, 66, 12);
     $d->wire(29,  7, 42,  3);
     $d->wire(29, 12, 42,  8);
     $d->wire(49,  2, 66,  2);
     $d->wire(57,  7, 70,  4);
     $d->wire(53, 12, 66, 14);
     $d->wire(57, 12, 70, 10);
     $d->wire(61,  2, 70,  8);
     $d->wire(17, 14, 22,  5);
     $d->wire(25,  2, 34,  7);
     $d->wire(29,  4, 38,  9);
     $d->wire(29,  9, 38, 14);
     $d->wire(33,  4, 46,  3);
     $d->wire(21, 14, 30, 10);
     $d->wire(29, 14, 42, 14);
     $d->wire(57,  2, 70,  2);
     $d->wire(65,  7, 74,  4);
     $d->wire(21,  7, 30,  5);
     $d->wire(29,  2, 38,  4);
     $d->wire(65, 12, 74, 10);
     $d->wire(69,  2, 74,  8);
     $d->wire(21,  2, 26,  7);
     $d->wire(25,  4, 34,  5);
     $d->wire(69,  7, 74, 12);
     $d->wire(81,  2, 82, 11);
     $d->wire(21, 12, 30, 12);
     $d->wire(65,  2, 74,  2);
     $d->wire(21,  9, 26, 12);
     $d->wire(73,  7, 78,  4);
     $d->wire(77, 12, 82,  9);
     $d->wire(69, 12, 74, 14);
     $d->wire(21,  4, 26,  5);
     $d->wire(77,  7, 82,  6);
   $d->layout;
   $d->svg(svg=>"testp");
 }

#latest:;
if (1)                                                                          #
 {my $d = Silicon::Chip::Wiring::new(width=>1528, height=>232);
  $d->wire(179, 216, 1324, 39);
  $d->wire(179, 224, 1324, 51);
  $d->wire(47,  48,  1144, 224);
  $d->wire(47,  40,  1144, 212);
  $d->wire(47,  32,  1144, 200);
  $d->wire(191, 136, 1324, 212);
  $d->wire(191, 128, 1324, 200);
  $d->wire(191, 120, 1324, 188);
  $d->wire(191, 112, 1324, 176);
  $d->wire(191, 104, 1324, 164);
  $d->wire(191, 96,  1324, 152);
  $d->wire(35,  144, 1144, 68);
  $d->wire(191, 88,  1324, 140);
  $d->wire(179, 88,  1312, 39);
  $d->wire(35,  152, 1144, 80);
  $d->wire(191, 80,  1324, 128);
  $d->wire(179, 96,  1312, 51);
  $d->wire(35,  160, 1144, 92);
  $d->wire(191, 72,  1324, 116);
  $d->wire(179, 104, 1312, 63);
  $d->wire(35,  168, 1144, 104);
  $d->wire(191, 64,  1324, 104);
  $d->wire(179, 112, 1312, 75);
  $d->wire(35,  176, 1144, 116);
  $d->wire(191, 56,  1324, 92);
  $d->wire(179, 120, 1312, 87);
  $d->wire(35,  184, 1144, 128);
  $d->wire(47,  192, 1192, 212);
  $d->wire(191, 48,  1324, 80);
  $d->wire(179, 128, 1312, 99);
  $d->wire(35,  192, 1144, 140);
  $d->wire(47,  184, 1192, 200);
  $d->wire(191, 40,  1324, 68);
  $d->wire(179, 136, 1312, 111);
  $d->wire(35,  200, 1144, 152);
  $d->wire(47,  176, 1192, 188);
  $d->wire(191, 32,  1324, 56);
  $d->wire(179, 144, 1312, 123);
  $d->wire(35,  208, 1144, 164);
  $d->wire(47,  168, 1192, 176);
  $d->wire(179, 152, 1312, 135);
  $d->wire(179, 152, 1312, 135);
  $d->layout;
  $d->svg(svg=>q(test2), pngs=>2);
 }

&done_testing;
finish: 1
