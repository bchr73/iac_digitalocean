# ${public-dns}

[issuers]
%{ for index, name in issuer-names ~}
${name} ansible_user=root ansible_host=${issuer-ips[index]} ansible_port=22
%{ endfor ~}

[verifiers]
%{ for index, name in verifier-names ~}
${name} ansible_user=root ansible_host=${verifier-ips[index]} ansible_port=22
%{ endfor ~}

[explorers]
%{ for index, name in explorer-names ~}
${name} ansible_user=root ansible_host=${explorer-ips[index]} ansible_port=22
%{ endfor ~}

[web-servers:children]
issuers
verifiers
explorers
