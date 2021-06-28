use strict;

use Time::HiRes; # High resolution alarm, sleep, gettimeofday, interval timers
use Time::Local; # Efficiently compute time from local and GMT time
use Time::Piece; # Object Oriented time objects
use Time::Seconds; # A simple API to convert seconds to other date values
use Time::tm; # Internal object used by Time::gmtime and Time::localtime

use POSIX qw(strftime);

#January - 31 days
#February - 28 days in a common year and 29 days in leap years
#March - 31 days
#April - 30 days
#May - 31 days
#June - 30 days
#July - 31 days
#August - 31 days
#September - 30 days
#October - 31 days
#November - 30 days
#December - 31 days

# leap years
# divisible by 4
#   except divisible by 100
#     except divisible by 400

sub IsLeapYear { # $ year
	my $year = shift;
	if ($year % 4) {
		#2001
		return 0;
	} else {
		if (!($year % 400)) {
			# 2000
			return 1;
		} else {
			if (!($year % 100)) {
				# 1900
				return 0;
			} else {
				# 2004
				return 1;
			}
		}
	}
} # IsLeapYear()

sub GetNumberOfDaysInMonth {
	my $year = shift;
	my $month = shift;

	# assume resonable inputs #todo sanity
	my $numberOfDays = 0;

	# january = 1

	if ($month == 1 || $month == 3 || $month == 5 || $month == 7 || $month == 8 || $month == 10 || $month == 12) {
		$numberOfDays = 31;
	} elsif ($month == 4 || $month == 6 || $month == 7 || $month == 9 || $month == 11) {
		$numberOfDays = 30;
	} elsif ($month == 2) {
		#february
		if (IsLeapYear($year)) {
			$numberOfDays = 29;
		} else {
			$numberOfDays = 28;
		}
	}
	return $numberOfDays;
}

use Time::Local;

#$time = timelocal($sec,$min,$hours,$mday,$mon,$year);
#$time = timegm($sec,$min,$hours,$mday,$mon,$year);

sub TestYear {
	my $year = shift;
	print "<h1>\n";
	print " $year \n";
	print "<h1>\n";

	my @months = qw(January February March April May June July August September October November December);

	for (my $month = 1; $month <= 12; $month++) {
		my $daysInMonth = GetNumberOfDaysInMonth($year, $month);

		print '<table style="display: inline-block" border=1>';
		print "\n";

		print '<tr><th colspan=7>' . $months[$month-1] . '</th></tr>';
		print "\n";

		my $time;
		my $timeString;

		my $time = timelocal(1, 1, 1, 1, $month - 1, $year);
		my $firstDay = strftime('%w', localtime($time));

		print '<tr>';

		my $started = 0;

		my $dayTime;
		my $dayOfWeek;

		my $day;

		for ($day = 1; $day < $daysInMonth; $day++) {
			$dayTime = timelocal(1, 1, 1, $day, $month-1, $year);
			$dayOfWeek = strftime('%w', localtime($dayTime));

			if (!$started) {
				print '<tr>';
				for my $dow (qw(Sun Mon Tue Wed Thu Fri Sat)) {
					print '<td>' . $dow . '</td>';
				}
				print '</tr>';
				print '<tr>';
				while ($firstDay) {
					$firstDay--;
					print '<td>' . '-' . '</td>';
				}
				$started = 1;
			}

			if ($dayOfWeek == 0 && $day > 1) {
				print '<tr>';
			}
			print '<td>' . $day . '</td>';

			if ($dayOfWeek == 6) {
				print '</tr>';
			}
			#print localtime($time);
			#print '=';
			#print scalar(localtime($time));

			#print "\n";
		}

		if ($dayOfWeek != 6) {
			while ((6 - $dayOfWeek) > 0) {
				print '<td>--</td>';
				$dayOfWeek++;
			}
			print '</tr>';
		}

		#$time = timelocal(1, 1, 1, 1, $month-1, $year);
		#$timeString = scalar(localtime($time));
		#my @lastDayArray = split(' ', $timeString);
		#my $lastDay = $firstDayArray[0];

		print '</tr>';

		print '</table>';
		print "\n";
	}
}

my $yearStart = 2021;
my $yearEnd = 2016;

for (my $year = $yearStart; $year != $yearEnd; $year--) {
	TestYear($year);
}





























1;