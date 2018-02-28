Host login.${vpc_name}
   ServerAliveInterval 120
   HostName ${login_public_ip}
   User ubuntu
   ForwardAgent yes

Host k8s.${vpc_name}
   ServerAliveInterval 120
   HostName ${k8s_ip}
   User ubuntu
   ForwardAgent yes
   ProxyCommand ssh ubuntu@login.${vpc_name} nc %h %p 2> /dev/null

