package Image::SVG::Transform;



use strict;
use warnings;

=head1 NAME

Image::SVG::Transform - read the "transform" attribute of an SVG element

=head1 SYNOPSIS

    use Image::SVG::Transform;
    my $transform = Image::SVG::Transform->new();
    $transform->extract_transforms('scale(0.5)');
    my $view_point = $transform->transform([5, 10]);

=head1 DESCRIPTION

This module parses and converts the contents of the transform attribute in SVG into
a series of array of hashes, and then provide a convenience method for doing point transformation
from the transformed space to the viewpoint space.

This is useful if you're doing SVG rendering, or if you are trying to estimate the length of shapes in an SVG file.

=head1 METHODS

The following methods are available.

=head2 new ()

Constructor for the class.  It takes no arguments.

=cut

use Moo;
use Math::Matrix;
use Math::Trig qw/deg2rad/;
use Ouch;

use namespace::clean;

=head2 transforms

The list of transforms that were extracted from the transform string that submitted to L<extract_transforms>.  Each transform will be a hashref with these keys:

=head3 type

The type of transformation (scale, translate, skewX, matrix, skewY, rotate).

=head3 params

An arrayref of hashrefs.  Each hashref has key for type (string) and params (arrayref of numeric parameters).

=cut

has transforms => (
    is => 'rwp',
    clearer   => 'clear_transforms',
    predicate => 'has_transforms',
);

=head2 has_transforms

Returns true if the object has any transforms.

=head2 clear_transforms

Clear the set of transforms

=cut

=head2 ctm

The combined transformation matrix for the set of transforms.  This is a C<Math::Matrix> object.

=cut

has ctm => (
    is   => 'rw',
    lazy => 1,
    clearer => 'clear_ctm',
    default => sub {
        my $self = shift;
        my $ctm = $self->_generate_matrix(0);
        my $idx = 1;
        while ($idx < scalar @{ $self->transforms }) {
            my $matrix = $self->_generate_matrix($idx);
            my $product = $matrix->multiply($ctm);
            $ctm = $product;
            $idx++;
        }
        return $ctm;
    },
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

=head2 extract_transforms ( $svg_transformation )

Parses the C<$svg_transformation> string, which is expected to contain a valid set of SVG transformations as described in section 7.6 of the SVG spec: L<https://www.w3.org/TR/SVG/coords.html#TransformAttribute>.  Unrecognized transformation types, or valid types with the wrong number of arguments, will cause C<Image::SVG::Transform> to C<croak> with an error message.

After it is done parsing, it updates the stored C<transforms> and clears the stored combined transformation matrix.

Passing in the empty string will clear the set of transformations.

In the following conditions, C<Image::SVG::Transform> will throw an exception using L<Ouch>:

=over 4

=item The transform string could not be parsed

=item The transform contains un unknown type

=item The type of transform has the wrong number of arguments

=back

=cut

sub extract_transforms {
    my $self      = shift;
    my $transform = shift;
    ##Possible transforms:
    ## scale (x [y])
    ## translate (x [y])
    ## Start with trimming
    $transform =~ s/^\s*//;
    $transform =~ s/^\s*$//;

    ##On the empty string, just reset the object
    if (! $transform) {
        $self->clear_transforms;
        $self->clear_ctm;
        return;
    }
    my @transformers = ();
    while ($transform =~ m/\G (\w+) \s* \( \s* ($numbers_re) \s* \) (?:$comma_wsp)? /gx ) {
        push @transformers, [$1, $2];
    }

    if (! @transformers) {
        ouch 'bad_transform_string', "Image::SVG::Transform: Unable to parse the transform string $transform";
    }
    my @transforms = ();
    foreach my $transformer (@transformers) {
        my ($transform_type, $params) = @{ $transformer };
        my @params = split $split_re, $params;
        ##Global checks
        ouch 'unknown_type', "Unknown transform $transform_type" unless exists $valid_transforms->{$transform_type};
        ouch 'no_parameters', "No parameters for transform $transform_type" unless scalar @params;
        ouch 'too_many_parameters', "Too many parameters ".scalar(@params). " for transform $transform_type" if scalar(@params) > $valid_transforms->{$transform_type};
        ##Command specific checks
        if ($transform_type eq 'rotate' && @params == 2) {
            ouch 'rotate_2', 'rotate transform may not have two parameters';
        }
        elsif ($transform_type eq 'matrix' && @params != 6) {
            ouch 'matrix_6', 'matrix transform must have exactly six parameters';
        }
        if ($transform_type eq 'rotate' && @params == 3) {
            ##Special rotate with pre- and post-translates
            push @transforms,
            {
                type => 'translate',
                params => [ $params[1], $params[2] ],
            },
            {
                type => 'rotate',
                params => [ $params[0], ],
            },
            {
                type => 'translate',
                params => [ -1*$params[1], -1*$params[2] ],
            },
        }
        else {
            push @transforms, {
                type => $transform_type,
                params => \@params,
            }
        }
    }
    $self->_set_transforms(\@transforms);
    $self->clear_ctm;
}

=head2 transform ( $point )

Using the stored set of one or more C<transforms>, transform C<$point> from the local coordinate system to viewport coordinate system.  The combined transformation matrix is cached so that it isn't recalculated everytime this method is called.

=cut

sub transform {
    my $self  = shift;
    my $point = shift;
    return $point unless $self->has_transforms;
    push @{ $point }, 0; ##pad with zero to make a 1x3 matrix
    my $userspace = Math::Matrix->new(
        [ $point->[0] ],
        [ $point->[1] ],
        [ 1 ],
    );
    my $viewport = $self->ctm->multiply($userspace);
    return [ $viewport->[0]->[0], $viewport->[1]->[0] ];
}

=head2 untransform ( $point )

The opposite of C<transform>.  It takes a point from the viewport coordinates and transforms them into the local coordinate system.

=cut

sub untransform {
    my $self  = shift;
    my $point = shift;
    return $point unless $self->has_transforms;
    push @{ $point }, 0; ##pad with zero to make a 1x3 matrix
    my $viewport = Math::Matrix->new(
        [ $point->[0] ],
        [ $point->[1] ],
        [ 1 ],
    );
    my $userspace = $self->ctm->invert->multiply($viewport);
    return [ $userspace->[0]->[0], $userspace->[1]->[0] ];
}

sub _generate_matrix {
    my $self = shift;
    my $index = shift;
    my $t = $self->transforms->[$index];
    my @matrix;
    if ($t->{type} eq 'translate') {
        my $tx = $t->{params}->[0];
        my $ty = defined $t->{params}->[1] ? $t->{params}->[1] : 0;
        @matrix = (
            [ 1, 0, $tx, ],
            [ 0, 1, $ty, ],
            [ 0, 0, 1, ],
        );
    }
    elsif ($t->{type} eq 'scale') {
        my $sx = $t->{params}->[0];
        my $sy = defined $t->{params}->[1] ? $t->{params}->[1] : $sx;
        @matrix = (
            [ $sx, 0,   0, ],
            [ 0,   $sy, 0, ],
            [ 0,   0,   1, ],
        );
    }
    elsif ($t->{type} eq 'rotate') {
        my $angle = deg2rad($t->{params}->[0]);
        my $cosa  = cos $angle;
        my $sina  = sin $angle;
        @matrix = (
            [ $cosa, -1*$sina,  0, ],
            [ $sina,    $cosa,  0, ],
            [ 0,            0,  1, ],
        );
    }
    elsif ($t->{type} eq 'skewX') {
        my $angle = deg2rad($t->{params}->[0]);
        my $tana  = tan $angle;
        @matrix = (
            [ 1, $tana,  0, ],
            [ 0,     1,  0, ],
            [ 0,     0,  1, ],
        );
    }
    elsif ($t->{type} eq 'skewY') {
        my $angle = deg2rad($t->{params}->[0]);
        my $tana  = tan $angle;
        @matrix = (
            [ 1,     0,  0, ],
            [ $tana, 1,  0, ],
            [ 0,     0,  1, ],
        );
    }
    elsif ($t->{type} eq 'matrix') {
        my $p = $t->{params};
        @matrix = (
            [ $p->[0], $p->[2],  $p->[4], ],
            [ $p->[1], $p->[3],  $p->[5], ],
            [ 0,       0,        1, ],
        );
    }
    return Math::Matrix->new(@matrix);
}

=head1 PREREQS

L<namespace::clean>
L<Math::Trig>
L<Math::Matrix>
L<Ouch>
L<Moo>

=head1 SUPPORT

=over

=item Repository

L<http://github.com/perlDreamer/Image-SVG-Transform>

=item Bug Reports

L<http://github.com/perlDreamer/Image-SVG-Transform/issues>

=back

=head1 AUTHOR

Colin Kuskie <colink_at_plainblack_dot_com>

=head1 SEE ALSO

L<Image::SVG::Path>
L<SVG::Estimate>

=head1 THANKS

Thank you to Ben Bullock, author of L<Image::SVG::Path> for the regular expressions for the parser.

=head1 LEGAL

This module is Copyright 2016 Plain Black Corporation. It is distributed under the same terms as Perl itself. 

=cut

1;
