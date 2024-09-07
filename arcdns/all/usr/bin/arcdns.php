#!/usr/bin/php -d open_basedir=/usr/syno/bin/ddns
<?php

if ($argc !== 5) {
    echo 'badparam';
    exit();
}

$account = (string)$argv[1];
$pwd = (string)$argv[2];
$hostname = (string)$argv[3];
$ip = (string)$argv[4];

// check the hostname contains '.'
if (strpos($hostname, '.') === true) {
    echo 'badparam';
    exit();
}

$url = 'https://arcdns.tech/update/' . $hostname . '/' . $pwd;

$req = curl_init();
curl_setopt($req, CURLOPT_URL, $url);
curl_setopt($req, CURLOPT_RETURNTRANSFER, true);
$res = curl_exec($req);
$json = json_decode($res, true);

if ($json['status'] !== 'Successfuly updated') {
    echo 'badauth';
    curl_close($req);
    exit();
} else {
    echo 'good';
    curl_close($req);
    exit();
}

?>