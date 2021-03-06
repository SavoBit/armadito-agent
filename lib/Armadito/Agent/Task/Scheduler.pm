package Armadito::Agent::Task::Scheduler;

use strict;
use warnings;
use base 'Armadito::Agent::Task';

use MIME::Base64;
use Data::Dumper;
use JSON;

sub new {
	my ( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	my $task = {
		name      => "Scheduler",
		antivirus => $self->{agent}->{antivirus}->getJobj()
	};

	$self->{scheduler} = {
		name        => $self->{agent}->{config}->{scheduler},
		confdetails => []
	};

	$self->{jobj}->{task} = $task;

	return $self;
}

sub sendSchedulerInfos {
	my ($self) = @_;

	$self->{jobj}->{task}->{obj} = $self->{scheduler};
	my $json_text = to_json( $self->{jobj} );

	my $response = $self->{glpi_client}->sendRequest(
		url     => $self->{agent}->{config}->{server}[0] . "/api/schedulers",
		message => $json_text,
		method  => "POST"
	);

	if ( $response->is_success() ) {
		$self->{logger}->info("Send Scheduler infos successful...");
	}
	else {
		$self->_handleError($response);
		$self->{logger}->info("Send Scheduler infos failed...");
	}
}

1;

__END__

=head1 NAME

Armadito::Agent::Task::Scheduler - base class used for task scheduling management

=head1 DESCRIPTION

This task inherits from L<Armadito::Agent::Task>. It allows a remote management for agent's task scheduling solutions.

=head1 FUNCTIONS

=head2 run ( $self, %params )

Run the task.

=head2 new ( $self, %params )

Instanciate Task.

