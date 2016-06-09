package Image::SVG::Transform;
use strict;
use warnings;

=head1 NAME

Image::SVG::Transform - read the "transform" attribute of an SVG element

=head1 SYNOPSIS

    use Image::SVG::Transform;
    my $transform = Image::SVG::Transform->new(transform => 'scale(0.5)');
    $transform->extract_transforms();
    my $view_point = $transform->untransform([5, 10]);

=head1 DESCRIPTION

This module parses and converts the contents of the transform attribute in SVG into
a series of array of hashes, and then provide a convenience method for doing point transformation
from the transformed space to the viewpoint space.

=cut

use warnings;
use strict;
use Moo;
use Carp qw/croak/;

our $VERSION = '0.01';

has transform => (
    is => 'ro',
    required => 1,
);

has transforms => (
    is => 'rw',
    default => sub { [] },
);

##Borrowed parsing code from Image::SVG::Path
my $split_re = qr/
		     (?:
			 ,
		     |
			 (?<!e)(?=-)
		     |
			 \s+
		     )
		 /x;

my $comma_wsp = qr/ (?: \s+ ,? \s*)|(?: , \s* )/x;
my $number_re = qr/[-0-9.,e]+/i;
my $numbers_re = qr/(?:$number_re|\s)*/;

my $valid_transforms = {
    scale     => 2,
    translate => 2,
    rotate    => 3,
    skewX     => 1,
    skewY     => 1,
    matrix    => 6,
};

sub extract_transforms {
    my $self = shift;
    my $transform = shift || $self->transform;
    ##Possible transforms:
    ## scale (x [y])
    ## translate (x [y])
    ## Start with trimming
    $transform =~ s/^\s*//;
    $transform =~ s/^\s*$//;

    my @transformers = ();
    while ($transform =~ m/\G (\w+) \s* \( \s* ($numbers_re) \s* \) (?:$comma_wsp)? /gx ) {
        push @transformers, [$1, $2];
    }

    if (! @transformers) {
        croak "Image::SVG::Transform: Unable to parse the transform string $transform";
    }
    my @transforms = ();
    foreach my $transformer (@transformers) {
        my ($transform_type, $params) = @{ $transformer };
        my @params = split $split_re, $params;
        ##Global checks
        croak "Unknown transform $transform_type" unless exists $valid_transforms->{$transform_type};
        croak "No parameters for transform $transform_type" unless scalar @params;
        croak "Too many parameters ".scalar(@params). " for transform $transform_type" if scalar(@params) > $valid_transforms->{$transform_type};
        ##Command specific checks
        if ($transform_type eq 'rotate' && @params == 2) {
            croak 'rotate transform may not have two parameters';
        }
        elsif ($transform_type eq 'matrix' && @params != 6) {
            croak 'matrix transform must have exactly six parameters';
        }
        push @transforms, {
            type => $transform_type,
            params => \@params,
        }
    }
    $self->transforms(\@transforms);
}

1;
