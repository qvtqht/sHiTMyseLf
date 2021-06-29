select
	key||','||date 
from
	config
where
	key||','||date in
		(
			select
				key||','||date
			from
				config
			group by key
			order by date desc
		)
