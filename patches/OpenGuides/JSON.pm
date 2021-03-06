package OpenGuides::JSON;

use strict;

use vars qw( $VERSION );
$VERSION = '0.01';

use Wiki::Toolkit::Plugin::JSON;
use Time::Piece;
use URI::Escape;
use Carp 'croak';

sub new {
    my ( $class, @args ) = @_;
    my $self = {};
    bless $self, $class;
    $self->_init(@args);
}

sub _init {
    my ( $self, %args ) = @_;

    my $wiki = $args{wiki};

    unless ( $wiki && UNIVERSAL::isa( $wiki, "Wiki::Toolkit" ) ) {
        croak "No Wiki::Toolkit object supplied.";
    }
    $self->{wiki} = $wiki;

    my $config = $args{config};

    unless ( $config && UNIVERSAL::isa( $config, "OpenGuides::Config" ) ) {
        croak "No OpenGuides::Config object supplied.";
    }
    $self->{config} = $config;

    $self->{make_node_url} = sub {
        my ( $node_name, $version ) = @_;

        my $config = $self->{config};

        my $node_url =
          $config->script_url;
	if ($config->script_name ) {	
	  $node_url .= uri_escape( $config->script_name ) . '?'; 
	}
        $node_url .= 'id=' if defined $version;
        $node_url .=
          uri_escape(
            $self->{wiki}->formatter->node_name_to_node_param($node_name) );
        $node_url .= ';version=' . uri_escape($version) if defined $version;

        $node_url;
    };
    $self->{site_name}        = $config->site_name;
    $self->{default_city}     = $config->default_city || "";
    $self->{default_country}  = $config->default_country || "";
    $self->{site_description} = $config->site_desc || "";
    $self->{og_version}       = $args{og_version};

    $self;
}

sub emit_json {
    my ( $self, %args ) = @_;

    my $node_name = $args{node};
    my $wiki      = $self->{wiki};

    my %node_data          = $wiki->retrieve_node($node_name);
    my $data = {};
    $data->{phone}              = $node_data{metadata}{phone}[0] || '';
    $data->{fax}                = $node_data{metadata}{fax}[0] || '';
    $data->{website}            = $node_data{metadata}{website}[0] || '';
    $data->{opening_hours_text} = $node_data{metadata}{opening_hours_text}[0] || '';
    $data->{address}            = $node_data{metadata}{address}[0] || '';
    $data->{postcode}           = $node_data{metadata}{postcode}[0] || '';
    $data->{city}     = $node_data{metadata}{city}[0] || $self->{default_city};
    $data->{country}  = $node_data{metadata}{country}[0] || $self->{default_country};
    $data->{latitude} = $node_data{metadata}{latitude}[0] || '';
    $data->{longitude}  = $node_data{metadata}{longitude}[0] || '';
    $data->{version}    = $node_data{version};
    $data->{username}   = $node_data{metadata}{username}[0] || '';
    $data->{os_x}       = $node_data{metadata}{os_x}[0] || '';
    $data->{os_y}       = $node_data{metadata}{os_y}[0] || '';
    $data->{categories} = $node_data{metadata}{category} || [];
    $data->{locales}    = $node_data{metadata}{locale} || [];
    $data->{summary}    = $node_data{metadata}{summary}[0] || '';

    $data->{timestamp} = $node_data{last_modified};

    # Make a Time::Piece object.
    my $timestamp_fmt = $Wiki::Toolkit;

    if ($data->{timestamp}) {
        my $time = Time::Piece->strptime( $data->{timestamp}, $timestamp_fmt );
        $data->{timestamp} = $time->strftime("%Y-%m-%dT%H:%M:%S");
    }

    $data->{url}					= $self->{make_node_url}->( $node_name, $data->{version} );
    $data->{version_indpt_url}	= $self->{make_node_url}->($node_name);
	return $self->json_maker->make_json($data);
}

sub json_maker {
    my $self = shift;

    # OAOO, please.
    unless ( $self->{json_maker} ) {
        $self->{json_maker} = Wiki::Toolkit::Plugin::JSON->new(
            wiki                => $self->{wiki},
            site_name           => $self->{site_name},
            site_url            => $self->{config}->script_url,
            site_description    => $self->{site_description},
            make_node_url       => $self->{make_node_url},
            recent_changes_link => $self->{config}->script_url . '?action=rc',
            software_name       => 'OpenGuides',
            software_homepage   => 'http://openguides.org/',
            software_version    => $self->{og_version},
        );
    }

    return $self->{json_maker};
}

sub make_recentchanges_rss {
    my ( $self, %args ) = @_;

    $self->json_maker->recent_changes(%args);
}

sub rss_timestamp {
    my ( $self, %args ) = @_;

    $self->json_maker->rss_timestamp(%args);
}

=head1 NAME

OpenGuides::RDF - An OpenGuides plugin to output RDF/XML.

=head1 DESCRIPTION

Does all the RDF stuff for OpenGuides.  Distributed and installed as
part of the OpenGuides project, not intended for independent
installation.  This documentation is probably only useful to OpenGuides
developers.

=head1 SYNOPSIS

    use Wiki::Toolkit;
    use OpenGuides::Config;
    use OpenGuides::RDF;

    my $wiki = Wiki::Toolkit->new( ... );
    my $config = OpenGuides::Config->new( file => "wiki.conf" );
    my $rdf_writer = OpenGuides::RDF->new( wiki   => $wiki,
                                         config => $config ); 

    # RDF version of a node.
    print "Content-Type: application/rdf+xml\n\n";
    print $rdf_writer->emit_rdfxml( node => "Masala Zone, N1 0NU" );

    # Ten most recent changes.
    print "Content-Type: application/rdf+xml\n";
    print "Last-Modified: " . $self->rss_timestamp( items => 10 ) . "\n\n";
    print $rdf_writer->make_recentchanges_rss( items => 10 );

=head1 METHODS

=over 4

=item B<new>

    my $rdf_writer = OpenGuides::RDF->new( wiki   => $wiki,
                                           config => $config ); 

C<wiki> must be a L<Wiki::Toolkit> object and C<config> must be an
L<OpenGuides::Config> object.  Both arguments mandatory.


=item B<emit_rdfxml>

    $wiki->write_node( "Masala Zone, N1 0NU",
		     "Quick and tasty Indian food",
		     $checksum,
		     { comment  => "New page",
		       username => "Kake",
		       locale   => "Islington" }
    );

    print "Content-Type: application/rdf+xml\n\n";
    print $rdf_writer->emit_rdfxml( node => "Masala Zone, N1 0NU" );

B<Note:> Some of the fields emitted by the RDF/XML generator are taken
from the node metadata. The form of this metadata is I<not> mandated
by L<Wiki::Toolkit>. Your wiki application should make sure to store some or
all of the following metadata when calling C<write_node>:

=over 4

=item B<postcode> - The postcode or zip code of the place discussed by the node.  Defaults to the empty string.

=item B<city> - The name of the city that the node is in.  If not supplied, then the value of C<default_city> in the config object supplied to C<new>, if available, otherwise the empty string.

=item B<country> - The name of the country that the node is in.  If not supplied, then the value of C<default_country> in the config object supplied to C<new> will be used, if available, otherwise the empty string.

=item B<username> - An identifier for the person who made the latest edit to the node.  This person will be listed as a contributor (Dublin Core).  Defaults to empty string.

=item B<locale> - The value of this can be a scalar or an arrayref, since some places have a plausible claim to being in more than one locale.  Each of these is put in as a C<Neighbourhood> attribute.

=item B<phone> - Only one number supported at the moment.  No validation.

=item B<website> - No validation.

=item B<opening_hours_text> - A freeform text field.

=back

=item B<json_maker>

Returns a raw L<Wiki::Toolkit::Plugin::JSON> object created with the values you
invoked this module with.

=item B<make_recentchanges_rss>

    # Ten most recent changes.
    print "Content-Type: application/rdf+xml\n";
    print "Last-Modified: " . $rdf_writer->rss_timestamp( items => 10 ) . "\n\n";
    print $rdf_writer->make_recentchanges_rss( items => 10 );

    # All the changes made by bob in the past week, ignoring minor edits.

    my %args = (
                 days               => 7,
                 ignore_minor_edits => 1,
                 filter_on_metadata => { username => "bob" },
               );

    print "Content-Type: application/rdf+xml\n";
    print "Last-Modified: " . $rdf_writer->rss_timestamp( %args ) . "\n\n";
    print $rdf_writer->make_recentchanges_rss( %args );

=item B<rss_timestamp>

    print "Last-Modified: " . $rdf_writer->rss_timestamp( %args ) . "\n\n";

Returns the timestamp of the RSS feed in POSIX::strftime style ("Tue, 29 Feb 2000 
12:34:56 GMT"), which is equivalent to the timestamp of the most recent item
in the feed. Takes the same arguments as make_recentchanges_rss(). You will most 
likely need this to print a Last-Modified HTTP header so user-agents can determine
whether they need to reload the feed or not.

=back

=head1 SEE ALSO

=over 4

=item * L<Wiki::Toolkit>

=item * L<http://openguides.org/>

=item * L<http://chefmoz.org/>

=back

=head1 AUTHOR

The OpenGuides Project (openguides-dev@openguides.org)

=head1 COPYRIGHT

Copyright (C) 2003-2005 The OpenGuides Project.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 CREDITS

Code in this module written by Kake Pugh and Earle Martin.  Dan Brickley, Matt 
Biddulph and other inhabitants of #swig on irc.freenode.net gave useful feedback 
and advice.

=cut

1;
