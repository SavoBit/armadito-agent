package Armadito::Agent::Task::Runjobs::Armadito;

use strict;
use warnings;
use base 'Armadito::Agent::Task::Runjobs';

use FusionInventory::Agent::Config;
use FusionInventory::Agent::Logger;
use Data::Dumper;
use MIME::Base64;
use JSON;

sub isEnabled {
	my ($self) = @_;

	return 1;
}

sub new {
	my ( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	return $self;
}

sub _runJob {
	my ( $self, $job ) = @_;

	my $config = ();
	my $class  = "Armadito::Agent::Task::$job->{job_type}::$self->{jobj}->{task}->{antivirus}->{name}";

	my $error_code = 1;
	eval { $class->require(); };
	goto ERROR if ($@);

	$error_code = 2;
	goto ERROR if ( !$class->isEnabled() );

	$error_code = 3;
	eval {
		my $task = $class->new( config => $config, agent => $self->{agent}, job => $job );
		$task->run();
	};
	goto ERROR if ($@);

	$self->{jobj}->{task}->{obj} = {
		code    => 0,
		message => "runJob successful",
		job_id  => $job->{job_id}
	};

	return $self;

ERROR:

	# We send error as base64
	$self->{logger}->error($@);
	$self->{jobj}->{task}->{obj} = {
		code    => $error_code,
		message => encode_base64($@),
		job_id  => $job->{job_id}
	};

	return $self;
}

sub _runJobs {
	my ($self) = @_;

	foreach my $job ( @{ $self->{jobs} } ) {
		if ( $job->{antivirus_name} eq "Armadito" ) {
			$self->_runJob($job);
			$self->_sendStatus();
			$self->_rmJobFromStorage( $job->{job_id} );
		}
	}

	return $self;
}

sub _handleResponse {

	my ( $self, $response ) = @_;

	$self = $self->SUPER::_handleResponse($response);

	return $self;
}

sub _handleError {

	my ( $self, $response ) = @_;

	$self = $self->SUPER::_handleError($response);

	return $self;
}

sub _sendStatus {
	my ($self) = @_;

	my $json_text = to_json( $self->{jobj} );

	my $response = $self->{glpi_client}->sendRequest(
		"url"   => $self->{agent}->{config}->{armadito}->{server}[0] . "/api/jobs",
		message => $json_text,
		method  => "POST"
	);

	if ( $response->is_success() ) {
		$self->_handleResponse($response);
		$self->{logger}->info("Runjobs sendStatus successful...");
	}
	else {
		$self->_handleError($response);
		$self->{logger}->info("Runjobs sendStatus failed...");
	}
}

sub run {
	my ( $self, %params ) = @_;

	$self = $self->SUPER::run(%params);
	$self = $self->_runJobs();

	return $self;
}
1;

__END__

=head1 NAME

Armadito::Agent::Task::Runjobs::Armadito - Runjobs Task for Armadito Antivirus.

=head1 DESCRIPTION

This task inherits from L<Armadito::Agent::Task::Runjobs>. Run Armadito jobs and send results to /jobs REST API of Armadito Plugin for GLPI.

=head1 FUNCTIONS

=head2 isEnabled ( $self )

Returns true if the task is enabled.

=head2 run ( $self, %params )

Run the task.

=head2 new ( $self, %params )

Instanciate Task.



