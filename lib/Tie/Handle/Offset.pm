use strict;
use warnings;

package Tie::Handle::Offset;
# ABSTRACT: Tied handle that hides the beginning of a file
# VERSION

use parent qw/Tie::Handle/;
use Scalar::Util qw( refaddr weaken );

#--------------------------------------------------------------------------#
# Inside-out data storage and accessor
#--------------------------------------------------------------------------#

my %HEAD_OFF = ();

sub offset {
  my $self = shift;
  if ( @_ ) {
    return $HEAD_OFF{ refaddr $self } = shift;
  }
  else {
    return $HEAD_OFF{ refaddr $self };
  }
}

# Track objects for thread-safety

my %REGISTRY = ();

#--------------------------------------------------------------------------#
# Tied handle methods
#--------------------------------------------------------------------------#

sub TIEHANDLE
{
  my $class = shift;
  my $params;
  $params = pop if ref $_[-1] eq 'HASH';

  my $self    = \do { no warnings 'once'; local *HANDLE};
  bless $self,$class;
  my $id = refaddr $self;
  weaken( $REGISTRY{ $id } = $self );
  $self->OPEN(@_) if (@_);
  if ( $params->{offset} ) {
    $HEAD_OFF{ $id } = $params->{offset};
    seek($self, $HEAD_OFF{ $id }, 0);
  }
  return $self;
}

sub TELL    {
  my $cur = tell($_[0]) - $HEAD_OFF{ refaddr $_[0] };
  # XXX shouldn't ever be less than zero, but just in case...
  return $cur > 0 ? $cur : 0;
}

sub SEEK    {
  my ($self, $pos, $whence) = @_;
  my $id = refaddr $self;
  my $rc;
  if ( $whence == 0 || $whence == 1 ) { # pos from start, cur
    $rc = seek($self, $pos + $HEAD_OFF{ $id }, $whence);
  }
  elsif ( _size($self) + $pos < $HEAD_OFF{$id} ) { # from end
    $rc = '';
  }
  else {
    $rc = seek($self,$pos,$whence);
  }
  return $rc;
}

sub OPEN
{
  my $id = refaddr $_[0];
  $HEAD_OFF{ $id } = 0;
  $_[0]->CLOSE if defined($_[0]->FILENO);
  @_ == 2 ? open($_[0], $_[1]) : open($_[0], $_[1], $_[2]);
}

sub _size {
  my ($self) = @_;
  my $cur = tell($self);
  seek($self,0,2); # end
  my $size = tell($self);
  seek($self,$cur,0); # reset
  return $size;
}

#--------------------------------------------------------------------------#
# Methods copied from Tie::StdHandle to avoid dependency on Perl 5.8.9/5.10.0
#--------------------------------------------------------------------------#

sub EOF     { eof($_[0]) }
sub FILENO  { fileno($_[0]) }
sub CLOSE   { close($_[0]) }
sub BINMODE { binmode($_[0]) }
sub READ     { read($_[0],$_[1],$_[2]) }
sub READLINE { my $fh = $_[0]; <$fh> }
sub GETC     { getc($_[0]) }

sub WRITE
{
 my $fh = $_[0];
 print $fh substr($_[1],0,$_[2])
}

#--------------------------------------------------------------------------#
# DESTROY()
#--------------------------------------------------------------------------#

sub DESTROY {
    my $self = shift;
    delete $HEAD_OFF{ refaddr $self };
    delete $REGISTRY{ refaddr $self };
}

#--------------------------------------------------------------------------#
# CLONE()
#--------------------------------------------------------------------------#

sub CLONE {
    for my $old_id ( keys %REGISTRY ) {

        # look under old_id to find the new, cloned reference
        my $object = $REGISTRY{ $old_id };
        my $new_id = refaddr $object;

        # relocate data
        $HEAD_OFF{ $new_id } = $HEAD_OFF{ $old_id };
        delete $HEAD_OFF{ $old_id };

        # update the weak reference to the new, cloned object
        weaken ( $REGISTRY{ $new_id } = $object );
        delete $REGISTRY{ $old_id };
    }

    return;
}

1;

=for Pod::Coverage method_names_here

=head1 SYNOPSIS

  use Tie::Handle::Offset;

  tie *FH, 'Tie::Handle::Offset', "<", $filename, { offset => 20 };

=head1 DESCRIPTION

This modules provides a file handle that hides the beginning of a file.
After opening, the file is positioned at the offset location. C<seek()> and
C<tell()> calls are modified to preserve the offset.

For example, C<tell($fh)> will return 0, though the actual file position
is at the offset.  Likewise, C<seek($fh,80,0)> will seek to 80 bytes from
the offset instead of 80 bytes from the actual start of the file.

=cut

# vim: ts=2 sts=2 sw=2 et:
