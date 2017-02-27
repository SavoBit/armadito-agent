package Armadito::Agent::Antivirus::Armadito::Task::Scan;

use strict;
use warnings;
use base 'Armadito::Agent::Task::Scan';
use IPC::System::Simple qw(capture $EXITVAL EXIT_ANY);
use Armadito::Agent::Tools::Time qw(secondsToDuration);
use JSON;

sub _parseScanOutput {
	my ($self) = @_;

	my @events = split( "\n\n", $self->{output} );

	foreach my $event (@events) {
		my $jobj = from_json( $event, { utf8 => 1 } );

		if ( $jobj->{type} eq "EVENT_DETECTION" ) {
			my $alert = {
				detection_time => $jobj->{timestamp},
				filepath       => $jobj->{u}->{ev_detection}->{path},
				name           => $jobj->{u}->{ev_detection}->{module_report},
				action         => $jobj->{u}->{ev_detection}->{scan_action},
				module_name    => $jobj->{u}->{ev_detection}->{module_name}
			};
			push( @{ $self->{alerts} }, $alert );
		}
		elsif ( $jobj->{type} eq "EVENT_ON_DEMAND_COMPLETED" ) {
			$self->{results}->{scanned_count}    = $jobj->{u}->{ev_on_demand_completed}->{total_scanned_count};
			$self->{results}->{malware_count}    = $jobj->{u}->{ev_on_demand_completed}->{total_malware_count};
			$self->{results}->{suspicious_count} = $jobj->{u}->{ev_on_demand_completed}->{total_suspicious_count};
		}
	}

	$self->_setResults();
}

sub _setResults {
	my ($self) = @_;

	$self->{results}->{progress} = 100;
	$self->{results}->{job_id}   = $self->{job}->{job_id};
	$self->{results}->{duration} = secondsToDuration( $self->{end_time} - $self->{start_time} );
}

sub _execScan {
	my ($self) = @_;

	my $bin_path     = $self->{agent}->{antivirus}->{program_path} . "armadito-scan";
	my $scan_path    = $self->{job}->{obj}->{scan_path};
	my $scan_options = $self->{job}->{obj}->{scan_options};
	my $cmdline      = "\"" . $bin_path . "\" --json " . $scan_options . " \"" . $scan_path . "\"";

	$self->{start_time} = time;
	$self->{output}     = capture( EXIT_ANY, $cmdline );
	$self->{end_time}   = time;
	$self->{logger}->debug2( $self->{output} );

	if ( $EXITVAL != 0 ) {
		die "CLI scan failed.";
	}
}

sub run {
	my ( $self, %params ) = @_;

	$self = $self->SUPER::run(%params);

	$self->_execScan();
	$self->_parseScanOutput();
	$self->sendScanResults();
	$self->sendScanAlerts();

	return $self;
}

1;

__END__

=head1 NAME

Armadito::Agent::Antivirus::Armadito::Task::Scan - Scan Task for Armadito Antivirus.

=head1 DESCRIPTION

This task inherits from L<Armadito::Agent::Task:Scan>. Launch an Armadito Antivirus on-demand scan using AV's API REST protocol and then send a brief report in a json formatted POST request to Armadito plugin for GLPI.

=head1 FUNCTIONS

=head2 run ( $self, %params )

Run the task.

=head2 new ( $self, %params )

Instanciate Task.

