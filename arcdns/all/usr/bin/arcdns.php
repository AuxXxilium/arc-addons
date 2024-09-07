#!/usr/bin/php -d open_basedir=/usr/syno/bin/ddns
<?php
/*
Usage Instructions ( Obviously your domain has to be hosted on ArcDNS )

1) Copy this file to /usr/syno/bin/ddns/arcdns.php

2) Add the following entry in /etc.defaults/ddns_provider.conf
[Custom - ArcDNS]
        modulepath=/usr/syno/bin/ddns/arcdns.php
        queryurl=dyn.arcdns.tech

3) In Synology External Access > DDNS
Hostname = subdomain.domain.com OR domain.com 
Username = put-random-string-here-for-validation-purpose
Password = ArcDNS DDNS Token (Accounts > Domain List > Advanced DNS)
*/

if ($argc !== 5) {
    echo 'badparam';
    exit();
}

$account = (string)$argv[1];
$pwd = (string)$argv[2];
$hostname = (string)$argv[3];
$ip = (string)$argv[4];

// check the hostname contains '.'
if (strpos($hostname, '.') === false) {
    echo 'badparam';
    exit();
}

// only for IPv4 format
if (!filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
    echo "badparam";
    exit();
}

$array = explode('.', $hostname);
if (count($array) >= 3) {
    $domain = implode('.', array_slice($array, 1));
    $hostname = implode('.', array_slice($array, 0, 1));
} else {
    $domain = implode('.', $array);
    $hostname = '@';
}

$url = 'https://arcdns.tech/update/'.$hostname.'/'.$pwd.;

$req = curl_init();
curl_setopt($req, CURLOPT_URL, $url);
curl_setopt($req, CURLOPT_RETURNTRANSFER, true);
$res = curl_exec($req);
curl_close($req);

$xml = new SimpleXMLElement($res);
if ($xml->ErrCount > 0) {
    $error = $xml->errors[0]->Err1;
    if (strcmp($error, "This hostname has not been registered or is expired.") === 0) {
        echo "nohost";
    } elseif (strcmp($error, "You have supplied the wrong token to manipulate this host") === 0) {
        echo "badauth";
    } else {
        echo "911 [".$error."]";
    }
} else {
    echo "good";
}