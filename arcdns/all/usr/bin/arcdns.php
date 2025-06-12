#!/usr/bin/php -d open_basedir=/usr/syno/bin/ddns
<?php

$account = (string)$argv[1];
$pwd = (string)$argv[2];
$hostname = (string)$argv[3];
$ip = (string)$argv[4];

// Split hostname to extract domain
$parts = explode('.', $hostname, 2);
if (count($parts) === 2) {
    $hostname = $parts[0];
    $domain = $parts[1];
} else {
    echo 'badparam';
    exit();
}

$url = 'https://arc.auxxxilium.tech/update?hostname=' . urlencode($hostname) . '&password=' . urlencode($pwd) . '&domain=' . urlencode($domain);

$req = curl_init();
curl_setopt($req, CURLOPT_URL, $url);
curl_setopt($req, CURLOPT_RETURNTRANSFER, true);
$res = curl_exec($req);
$json = json_decode($res, true);

if ($json['success'] !== true) {
    echo 'badauth';
    curl_close($req);
    exit();
} else {
    echo 'good';
    curl_close($req);
    exit();
}

?>