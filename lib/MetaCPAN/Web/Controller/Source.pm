package MetaCPAN::Web::Controller::Source;

use Moose;
use namespace::autoclean;

BEGIN { extends 'MetaCPAN::Web::Controller' }

sub index : Path : Args {
    my ( $self, $c, @module ) = @_;

    if ( $c->req->params->{raw} ) {
        $c->detach( 'raw', \@module );
    }

    my ( $source, $module );
    if ( @module == 1 ) {
        $module = $c->model('API::Module')->find(@module)->get;
        @module = @{$module}{qw(author release path)};
        $source = $c->model('API::Module')->source(@module)->get;
    }
    else {
        ( $source, $module ) = map { $_->get } (
            $c->model('API::Module')->source(@module),
            $c->model('API::Module')->get(@module),
        );
    }
    if ( $module->{directory} ) {
        my $files = $c->model('API::File')->dir(@module)->get;

        $self->add_cache_headers( $c, $module );

        $c->stash( {
            template  => 'browse.html',
            files     => $files,
            author    => shift @module,
            release   => shift @module,
            directory => \@module,
        } );
    }
    elsif ( exists $source->{raw} ) {
        $module->{content} = $source->{raw};
        $c->stash( {
            file => $module,
        } );
        $c->forward('content');
    }
    else {
        $c->detach('/not_found');
    }
}

sub raw : Private {
    my ( $self, $c, @module ) = @_;

    if ( @module == 1 ) {
        my $module = $c->model('API::Module')->find(@module)->get;
        @module = @{$module}{qw(author release path)};
    }

    $c->res->redirect( $c->config->{api_external_secure}
            . '/source/'
            . join( '/', @module ) );
    $c->detach;
}

sub add_cache_headers {
    my ( $self, $c, $file ) = @_;

    $c->add_surrogate_key('SOURCE');
    $c->add_dist_key( $file->{distribution} );
    $c->add_author_key( $file->{author} );

    $c->browser_max_age('1h');
    $c->cdn_max_age('1y');

    $c->res->last_modified( $file->{date} );
}

sub content : Private {
    my ( $self, $c ) = @_;

    my $file = $c->stash->{file};

    $self->add_cache_headers( $c, $file );

    # could this be a method/function somewhere else?
    if ( !$file->{binary} ) {
        my $filetype = $self->detect_filetype($file);
        $c->stash( { source => $file->{content}, filetype => $filetype } );
    }
    $c->res->last_modified( $file->{date} );
    $c->stash( {
        template => 'source.html',
        file     => $file,
    } );
}

# Class method to ease testing.
sub detect_filetype {
    my ( $self, $file ) = @_;

    if ( defined( $file->{path} ) ) {
        local $_ = $file->{path};

        # No separate pod brush as of 2011-08-04.
        return 'perl' if /\. ( p[ml] | psgi | pod ) $/ix;

        return 'perl' if /^ (cpan|alien)file $/ix;

        return 'yaml' if /\. ya?ml $/ix;

        return 'javascript' if /\. js(on)? $/ix;

        return 'c' if /\. ( c | h | xs ) $/ix;

        # Are other changelog files likely to be in CPAN::Changes format?
        return 'cpanchanges' if /^ Changes $/ix;
    }

    # If no paths matched try mime type (which likely comes from the content).
    if ( defined( $file->{mime} ) ) {
        local $_ = $file->{mime};

        return 'perl' if /perl/;
    }

    # Default to plain text.
    return 'plain';
}

__PACKAGE__->meta->make_immutable;

1;
