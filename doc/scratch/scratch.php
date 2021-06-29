		if ($hnMode && length(c) > 6) {
			$c = trim($c);
			if (substr($c, length($c) - 6) == 'reply') {
				$c = substr($c, 0, length($c) - 5);
				$c = trim($c);
			}
		}
