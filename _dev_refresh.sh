#!/bin/sh

# notification

echo ====================================
echo Script about to reset configuration!
echo ====================================
echo You have 3 seconds to press Ctrl + C
echo ====================================
echo 3
sleep 2
echo 2
sleep 2
echo 1
sleep 2


# default/template
find default/template -type f | sort | xargs sha1sum | sha1sum | cut -d ' ' -f 1 > default_template_checksum_new

if ! diff ./default_template_checksum_new ./default_template_checksum
then
	# if checksum doesn't match last recorded, clear template cache
	echo default_template_checksum

	./_dev_clean_template.sh
	./_dev_clean_html.sh

	mv -v default_template_checksum_new default_template_checksum
fi


# default/template/php
find default/template/php -type f | sort | xargs sha1sum | sha1sum | cut -d ' ' -f 1 > php_templates_checksum_new

if ! diff ./php_templates_checksum_new ./php_templates_checksum
then
	echo php_templates_checksum

	./_dev_clean_template.sh
	./pages.pl --php

	mv -v php_templates_checksum_new php_templates_checksum
fi


# config
find config -type f | sort | xargs sha1sum | sha1sum | cut -d ' ' -f 1 > config_checksum_new

if ! diff ./config_checksum_new ./config_checksum
then
	echo config_checksum

	./_dev_clean_html.sh

	mv -v config_checksum_new config_checksum
fi



# html/image
find html/image -type f | sort | xargs sha1sum | sha1sum | cut -d ' ' -f 1 > html_image_checksum_new

if ! diff ./html_image_checksum_new ./html_image_checksum
then
	echo html_image_checksum

	time find html/image -cmin -100 | grep \\.txt$ | xargs ./index.pl

	mv -v html_image_checksum_new html_image_checksum
fi


# html/txt
find html/txt -type f | sort | xargs sha1sum | sha1sum | cut -d ' ' -f 1 > html_txt_checksum_new

if ! diff ./html_txt_checksum_new ./html_txt_checksum
then
	echo html_txt_checksum

	time find html/txt -cmin -100 | grep \\.txt$ | head -n 35 | xargs ./index.pl

	mv -v html_txt_checksum_new html_txt_checksum
fi


# access log
sha1sum log/access.log | cut -d ' ' -f 1 > access_log_checksum_new

if ! diff ./access_log_checksum_new ./access_log_checksum
then
	echo access_log_checksum

	./access_log_read.pl --all

	mv -v access_log_checksum_new access_log_checksum
fi
