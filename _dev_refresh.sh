#!/bin/sh



# access log
sha1sum log/access.log | cut -d ' ' -f 1 > access_log_checksum_new

if ! diff ./access_log_checksum_new ./access_log_checksum
then
	# if checksum doesn't match last recorded, clear html cache
	echo thanks
	time ./access_log_read.pl --all
	cp access_log_checksum_new_new access_log_checksum
fi



# php files
find default/template/php -type f | sort | xargs sha1sum | sha1sum | cut -d ' ' -f 1 > php_templates_checksum_new

if ! diff ./php_templates_checksum_new ./php_templates_checksum
then
	# if checksum doesn't match last recorded, clear html cache
	echo thanks
	time ./_dev_clean_template.sh ; ./pages.pl --php
	cp php_templates_checksum_new_new php_templates_checksum
fi



# calculate checksum of entire html/image tree
# and store it in ./html_image_checksum_new
find html/image -type f | sort | xargs sha1sum | sha1sum | cut -d ' ' -f 1 > html_image_checksum_new

if ! diff ./html_image_checksum_new ./html_image_checksum
then
	# if checksum doesn't match last recorded, clear html cache
	echo =====
	echo IMAGE
	echo =====
	time ./index.pl --all
	cp html_image_checksum_new html_image_checksum
	time ./_clean_html.sh
fi




# calculate checksum of entire html/txt tree
# and store it in ./html_txt_checksum_new
find html/txt -type f | sort | xargs sha1sum | sha1sum | cut -d ' ' -f 1 > html_txt_checksum_new

if ! diff ./html_txt_checksum_new ./html_txt_checksum
then
	# if checksum doesn't match last recorded, clear html cache
	echo thanks
	time ./index.pl --all
	cp html_txt_checksum_new html_txt_checksum
	time ./_clean_html.sh
fi




# calculate checksum of entire default/template tree
# and store it in ./default_template_checksum_new
find default/template -type f | sort | xargs sha1sum | sha1sum | cut -d ' ' -f 1 > default_template_checksum_new

if ! diff ./default_template_checksum_new ./default_template_checksum
then
	# if checksum doesn't match last recorded, clear html cache
	echo thanks
	time ./_clean_template.sh
	cp default_template_checksum_new default_template_checksum
fi





# calculate checksum of entire config tree
# and store it in ./config_checksum_new
find config -type f | sort | xargs sha1sum | sha1sum | cut -d ' ' -f 1 > config_checksum_new

if ! diff ./config_checksum_new ./config_checksum
then
	# if checksum doesn't match last recorded, clear html cache
	echo thanks
	time ./_clean_html.sh
	cp config_checksum_new config_checksum
fi
