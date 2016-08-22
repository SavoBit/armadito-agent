package Armadito::Agent::HTTP::Client::ArmaditoAV;

use strict;
use warnings;
use base 'FusionInventory::Agent::HTTP::Client';

use English qw(-no_match_vars);
use HTTP::Request;
use HTTP::Request::Common qw{ POST };
use UNIVERSAL::require;
use URI;
use Encode;
use Data::Dumper;
use URI::Escape;
use JSON;
use FusionInventory::Agent::Tools;

sub new {
	my ( $class, %params ) = @_;
	my $self = $class->SUPER::new(%params);

	# default options
	$self->{server_url} = "http://localhost:8888";

	return $self;
}

sub _prepareURL {
	my ( $self, %params ) = @_;

	my $url = ref $params{url} eq 'URI' ? $params{url} : URI->new( $params{url} );

	return $url;
}

sub send {
	my ( $self, %params ) = @_;

	my $url = $self->_prepareURL(%params);

	$self->{logger}->debug2($url) if $self->{logger};

	my $headers = HTTP::Headers->new(
		'User-Agent' => 'armadito-agent',
		'Referer'    => $url
	);

	$headers->header( 'Content-Type'     => 'application/json' ) if ( $params{method} eq 'POST' );
	$headers->header( 'X-Armadito-Token' => $self->{token} )     if ( defined( $self->{token} ) );

	my $request = HTTP::Request->new(
		$params{method} => $url,
		$headers
	);

	if ( $params{message} && $params{method} eq 'POST' ) {
		$request->content( encode( 'UTF-8', $params{message} ) );
	}

	return $self->request($request);
}

sub _handleRegisterResponse() {
	my ( $self, $response ) = @_;

	$self->{logger}->info( $response->content() );
	my $obj = from_json( $response->content(), { utf8 => 1 } );

	# Update armadito agent_id
	if ( defined( $obj->{token} ) ) {
		$self->{token} = $obj->{token};
		$self->{logger}->info( "ArmaditAV Registration successful, session token : " . $obj->{token} );
	}
	else {
		$self->{logger}->error("Invalid token from ArmaditAV registration.");
	}
}

sub register {
	my ($self) = @_;

	my $response = $self->send(
		"url"  => $self->{server_url} . "/api/register",
		method => "GET"
	);

	die "Unable to register to ArmaditoAV api." if ( !$response->is_success() || !$response->content() =~ /^\s*\{/ms );
	$self->_handleRegisterResponse($response);

}

1;
__END__

=head1 NAME

Armadito::Agent::HTTP::Client::ArmaditoAV - HTTP Client for armadito AV RESTful API.

=head1 DESCRIPTION

This is the class used by Armadito agent to communicate with armadito antivirus locally.

=head1 METHODS

=head2 $client->register()

Register to Armadito Antivirus API And set token after parsing AV json response.

=head2 $client->send(%params)

Send a request according to params given. If this is a GET request, params are formatted into URL with _prepareURL method. If this is a POST request, a message must be given in params. This should be a valid JSON message.

The following parameters are allowed, as keys of the %params hash :

=over

=item I<url>

the url to send the message to (mandatory)

=item I<method>

the method used: GET or POST. (mandatory)

=item I<message>

the message to send (mandatory if method is POST)

=back

The return value is a response object. See L<HTTP::Request> and L<HTTP::Response> for a description of the interface provided by these classes.