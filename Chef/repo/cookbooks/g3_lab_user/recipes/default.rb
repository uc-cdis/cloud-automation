#
# apt install a bunch of random stuff ...
#

include_recipe 'g3_dev_apt'

user 'gen3lab' do
  comment 'lab user'
  shell '/bin/bash'
  manage_home true
end

group 'gen3lab-docker' do
  action :manage
  group_name 'docker'
  members ['gen3lab']
  append true
end


execute 'g3-lab-setup' do
  cwd '/home/gen3lab'
  command <<-EOF
    (
      su gen3lab
      if [ ! -d ./compose-services ]; then
        git clone https://github.com/uc-cdis/compose-services.git
        cd ./compose-services
        bash ./creds_setup.sh "$(hostname).gen3workshop.org"
        sed -i 's/DICTIONARY_URL:/#DICTIONARY_URL:/g' docker-compose.yml
        sed -i 's/#\s*PATH_TO_SCHEMA_DIR:/PATH_TO_SCHEMA_DIR:/g' docker-compose.yml
        if [ -e /var/run/docker.sock ]; then
          docker-compose pull
        fi
      fi
    )
    chown -R gen3lab: /home/gen3lab/
    EOF
end

execute 'g3-lab-keys' do
  cwd '/tmp'
  # TODO - move the list of keys out to an attribute or databag ...
  command <<-EOF
(
  for dir in /home/ubuntu /home/gen3lab; do
    if [ -d "$dir" ]; then
      cd "$dir"
      if [ ! -f .ssh/authorized_keys ]; then
        mkdir -m 0700 -p .ssh
        touch .ssh/authorized_keys
        chown -R $(basename $dir): .ssh
        chmod -R 0700 .ssh
      fi
      (cat - <<EOM
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDVaMgmgl/6HsX39JW4lAMvFQpKVOtraLYKKT4K/N2dlnLMTxN2tpH07bz1qOSZyE6ecCwyX4xEINRkwPaqXDvxhdULL5+neZsu/JLDHJE4S0MBBlJanxgwt6hhqfg1FazrOSay820Rg+jpu4m4LINKQCh9mDSyY6Oca3Uavv+lbrdQWVAKWyYuN9lSNVWBuU+KC3eAWQ0GGClENJ0WFbPwJN7FJlHMpWf2CjoTqAkwF1EilxBLqKnJzZsd0kL0K9AbZRxNVo2odRyaXUlgXdgGksG0VJ8JIePp8O9AxId35qPYLFl66bCRH8crY+2Oif4E8/GaOhaU5y5ejqRgsr2fsJakVG+2m5o7EbFXB47hZ67Os02hQBGKdpBBd1zvGGIYB1HcLUDLRbqW7qEvTXQu+E4LiCXK3ZyGGY0WMCDaFXwil4lCj5aFL7Uwsks7eT+f19wZjTYHg/BeRiQWSvysom5sJ5JEC9o0C2OneH+jWQIZFBNo+CaRVkEDyA1ir7Lr4z8TDDnpGahSkUrSo1Ab9n0z2e1Nvt+68aYvMIEZd0YYs0J/+QoUHTIjThFAXq/LTK1TblMz/NKvAfOVc4eNwTLcbAvaM6Pu8OiHUISxN0tPwVRXySSW0zOn9RoajOdXGHbAAnsc/dmd7L/3fsnhVQhKTrRUq81ctwHEFl6BtQ== ribeyre@uchicago.edu
ssh-dss AAAAB3NzaC1kc3MAAACBAPfnMD7+UvFnOaQF00Xn636M1IiGKb7XkxJlQfq7lgyzWroUMwXFKODlbizgtoLmYToy0I4fUdiT4x22XrHDY+scco+3aDq+Nug+jaKqCkq+7Ms3owtProd0Jj6AWCFW+PPs0tGJiObieci4YqQavB299yFNn+jusIrDsqlrUf7xAAAAFQCi4wno2jigjedM/hFoEFiBR/wdlwAAAIBl6vTMb2yDtipuDflqZdA5f6rtlx4p+Dmclw8jz9iHWmjyE4KvADGDTy34lhle5r3UIou5o3TzxVtfy00Rvyd2aa4QscFiX5jZHQYnbIwwlQzguCiF/gtYNCIZit2B+R1p2XTR8URY7CWOTex4X4Lc88UEsM6AgXIpJ5KKn1pK2gAAAIAJD8p4AeJtnimJTKBdahjcRdDDedD3qTf8lr3g81K2uxxsLOudweYSZ1oFwP7RnZQK+vVE8uHhpkmfsy1wKCHrz/vLFAQfI47JDX33yZmBLtHjjfmYDdKVn36XKZ5XrO66vcbX2Jav9Hlqb6w/nekBx2nbJaZnHwlAp70RU13gyQ== renukarya@Renukas-MacBook-Pro.local
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCk0Z6Iy3mhEqcZLotIJd6j0nhq1F709M8+ttwaDKRg11kYbtRHxRv/ATpY8PEaDlaU3UlRhCBunbKhFVEdMiOfyi90shFp/N6gKr3cIzc6GPmobrSmpmTuHJfOEQB1i3p+lbEqI1aRj9vR/Ug/anjWd2dg+VBIi4kgX1hKVrEd1CHxySRYkIo+NTTwzglzEmcmp+u63sLjHiHXU055H5D6YwL3ussRVKw8UePpTeGO3tD+Y0ogyqByYdQWWTHckTwuvjIOTZ9T5wvh7CPSXT/je6Ddsq5mRqUopvyGKjHWaxO2s7TI9taQAvISE9rH5KD4hceRa81hzu3ZqZRw4in8IuSw5r8eG4ODjTEl0DIqa0C+Ui+MjSkfAZki0DjBf/HJbWe0c06MEJBorLjs9DHPQ5AFJUQqN7wk29r665zoK3zBdZG/JDXccZmptSMKVS02TxxzAON7oG66c9Kn7Vq6MBYcE3Sz7dxydm6PtvFIqij9KTfJdE+yw2o9seywB5yFfPkL63+hYZUaDFeJvvQSq5+7X2Cltn+F05J+EiORU5wO5oQWV01a2Yf6RT3o/728aYfaPjkdubwbCDWkdo8FaRqmK1NdQ8IoFprBjrhyDFwIXMEuVPrCJOUjL+ksXLPvYw2truiPfDxWxcvkVOAl4myfQOP4YqGmQ/IumYUbAw== thanhnd@uchicago.edu
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC+t+FKoTS4c+amC1EAD7uDC3YM54jaDtD6TAhSOw3mhXnS/erDvBUj/vgLlwx12Za8bDDtZyRzRSj3O3Tv51CUGLR1E6o/Y5olYN1pxW4Ftk24TiXHNEzyBqTViF3yosRBwjXSqRJq4Ooezoy5aHRciWQ6Y/DnARXH0MRh62ghgzzIMOUGOBN7nLn2KIh3hLCSFz7EAg7Dw/H80PvCT49XX8i5Nfs4GA/WV+3GPnQNOqahyw2B6jik7fWKLwmRFraIrWACll1SKs8sgPICgpNwDXOn+zTDOLedCLGCHRFrtNpdK+qsXhToyj2oxYyw4hdC1tWqLJhIEcm6M7eAM19N avantol@uchicago.edu
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCX+Tz7wVUpi00A/+Md+ndOBJPtASv4enTfA4eKDLAXME323Kro4vSLDo38SrJfPH3uYNVRDAKKH7jTi4eL4EbWQuoE7x/L2C9kz8yq047sWSQkpVkDugs4grG/yK/+D5rn+CvZb7c6qX3EKjyJ81p6/OJl2EdjHL6JCQw4Wnk97uUA5L64JeqzWWuhENtZS3Fgoa2lgSpcqiq517rCQqNTysG7dLCGE6m/DeiAWYaBs2QR3n7Jd9gyftmP1fMAvS3VEgPmTTK6KP+ewu2MA3Sx6Bg2JTSscFct5zQqya8u43r7qPiVqWsOrDZPrLh/cuDVP3h9VvICNpZsC8NlLaXNT0DtkRictfMNDIyARqw79OM1VwKJ4Jujp7sGtSDjeRWbqdN6+BsDfMv7WQ0Z+kiHhuAwtn6gWsJwmdcLaU0VPZ5owVnO2KRgHL260pOqK4xgZVPtoWlHDLUfrp2va1wJh4gJPgdWBTqu5mDhcSJdzC8pyOk4zIgjLWhg1vxJG3inVcJ5QBL5sbnzWUG+z/RGkjY6x93OncFYfdDdk9FnsUCelAnm/nAAPIDhwvnPRf1MmawClXU1/1NP4AEX8gkryjGPfC/5pFbd8hP2ocJGKeMRMX+XMPlPyqrX+Lg7IorleHsvqUxRKGosnXy/9uJCi0gsmHAW3zVTntxiMdhuNQ== zlchitty@uchicago.edu
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDBFbx4eZLZEOTUc4d9kP8B2fg3HPA8phqJ7FKpykg87w300H8uTsupBPggxoPMPnpCKpG4aYqgKC5aHzv2TwiHyMnDN7CEtBBBDglWJpBFCheU73dDl66z/vny5tRHWs9utQNzEBPLxSqsGgZmmN8TtIxrMKZ9eX4/1d7o+8msikCYrKr170x0zXtSx5UcWj4yK1al5ZcZieZ4KVWk9/nPkD/k7Sa6JM1QxAVZObK/Y9oA6fjEFuRGdyUMxYx3hyR8ErNCM7kMf8Yn78ycNoKB5CDlLsVpPLcQlqALnBAg1XAowLduCCuOo8HlenM7TQqohB0DO9MCDyZPoiy0kieMBLBcaC7xikBXPDoV9lxgvJf1zbEdQVfWllsb1dNsuYNyMfwYRK+PttC/W37oJT64HJVWJ1O3cl63W69V1gDGUnjfayLjvbyo9llkqJetprfLhu2PfSDJ5jBlnKYnEj2+fZQb8pUrgyVOrhZJ3aKJAC3c665avfEFRDO3EV/cStzoAnHVYVpbR/EXyufYTh7Uvkej8l7g/CeQzxTq+0UovNjRA8UEXGaMWaLq1zZycc6Dx/m7HcZuNFdamM3eGWV+ZFPVBZhXHwZ1Ysq2mpBEYoMcKdoHe3EvFu3eKyrIzaqCLT5LQPfaPJaOistXBJNxDqL6vUhAtETmM5UjKGKZaQ== emalinowski@uchicago.edu
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCebKYjShruq7mUT4/+g1AxyGYaCFspJmnSuaaTWjNn5VCA7HC2haVhrucftMMxXf4jArJYrR65R5QJult6vXI/6q/LtzCTE3VizW0C/hRGLcaQ+JFWAajZegw8MdcmbfaHE/NHovXmc7C6dSBspNn5AYFDLJpP1gYsYDMqJjhUO3dgAM2VIhA/Obrez6+v0BezCxR5HjBHFSqSRLhclYyf6TLCst+tmhRsSeBf0QvaefyEpIw37j35v0S6Z3dTcm1YfesaHTxyLnifMxrAOZmyVUyuI+fS6LR/gJ2rNkl+8d0dlZBToYlLYSzi+wq9/KGOq61BBBniIKkEnXx1nauw3wwUe2/Tec3Z/yZDZE0WOFvB1ByBGfIHXLa9InoBzjvtDtHeEhRAOGPZK5CrHhwH0HwRwSQxbcsrXSxxo2ZvcpH/jrtj5ZLkmy6z8APbjWtnIBuB0F1Q0cSqAChNScgSfPWHeOARQ2y5etlPaNmbPQxNEf5A69tYdctrpxG6uwWyNjYeL3CyoQ4kQEIS5Qz9kkKnQVgBGi4AasHxVKdVY9EykF0MxdOKM/Wc/I9xzH7Ln8PDn5k1CkYsjZ9WwtDDjrKclQ1YDq344AEYWiRKVWATp1aKo50hAkKrnaVAFCLe7jBRkCftdByZ6oXMe3UabG6nBmoxK97WwdBguaCw3Q== ginakuffel@MacBook-Pro.local
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC6zqeXcFwCaUUtRcyrDRR1uf8gyTkCwlIdWCyD1xqrk+0gnrwb/SDqGrsopI0Sm1hube6PPce+qCNf9ED7iK+4GJTDLBu986WCAK7lyxeBoh/QBewTZivPQ7MRLFZRa9OP8AlNV6xp0t9iF66sn/3U6y6aa5o1CaIxmvUpmrhWKpbPqnKMiu0Z45Bq6I+U5HLSDZD7tyenow8GxxwQL078jA1RGaO9rz3znZVKOaS1WVOxgECUFAUSwGFvcf4HiYgi6XP3GWlLv3cq56BZcBqslKTctwar0Mr6rQNFE6FGZN9rcgaSOB+HXza3Q0evcIYYIOQPLt31pyNcX4VYC/lz7PeU/K6GDjvr8BfWGNuEIA/nzvJUSRBxiJ+Aa394E/PaznBG3SK8Xl32v9w7YKiUFTuOjLSujYZ4rULogzFmKnfWhR3A1ar86dcsbiWn2rpDegFx5b2TEsJLuQg9sF6NN/0JkvDLmHJWUnzQUOnz3ns1Y+eYGo4MiBbwDMY4q49yiU7xxT5mxmUIAs95oavBiUhAuczFsKnF4WUHBPz0JrHxY3hFreGltRRnfsLDLzHtz0BkDiqHLrNclIk15S67yi2IgghmDi7/xR4H7TpiJApUfLzY+z5Ljs/K62Cn0606TzijP8lGC2INZIzpDj6LNpq/7somiQo0yYOlaapPTQ== garrettrup@Garretts-MacBook-Pro.local.cdis
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDCICX4r04oEWflEnrwwvFc7DObmPM0I0RisNLqezI/EvybT0LPwYYFLhquPkawFJ66l/Ud/MgHXQUw+Ois+UdLIzc2MGVY5/UlW0UW/ncwxWIwRQqpxQhpDGnaQaCdOTefoUCAwirR4PL3tsEDOX8cQZliQlo9tKABKkHRA1eHSFbqAnMf2G+yE1MoSClrZQcqUn88zVJxOmx6FgDnTrGGVs/JMkei/rgGurNeuz1Ttj+hQdrNEnUm6XdAwswoSUF0GMm0oVjG1aNurtx+fiiMefweDKgecz+dXeO/sf2W88+AxC1JdyL1fjYnGgsL29sgt6od0/N332XyPuU9vRG2S+HFKwb4LlZsAcZ7bb6c6YkuAJN0RunT3EBsMJx6rDjk3buTC156tUvJCqMYheQBGpI6mX77sZheKFvMAQvibq1vfp+xjqpr1qLzidMQkbirSr/l59S/BI0xImkfmWbhUGfdVaVj5dydMfuQqB4bEBhoTGc7F4GqL+9ZY0tUf3e5jkJjaJRuCFIPk6GWbvpbr4IGnRSrdYpSijOXcjh0HrSpSKtQWNLJLlFP5vdttwYmhZPyUvSg1zag2wZyCbhTllBBj1mKN8BLBaFoFPyEOGcBUv1Z/5cK1krg5MOzyP1aMZAGClSap9K4wrP+ZZUi+gQgaCc3q/hEXmkg/t6uJQ== peeyushpandey@Peeyushs-Air.SIIT.cdis
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDVaMgmgl/6HsX39JW4lAMvFQpKVOtraLYKKT4K/N2dlnLMTxN2tpH07bz1qOSZyE6ecCwyX4xEINRkwPaqXDvxhdULL5+neZsu/JLDHJE4S0MBBlJanxgwt6hhqfg1FazrOSay820Rg+jpu4m4LINKQCh9mDSyY6Oca3Uavv+lbrdQWVAKWyYuN9lSNVWBuU+KC3eAWQ0GGClENJ0WFbPwJN7FJlHMpWf2CjoTqAkwF1EilxBLqKnJzZsd0kL0K9AbZRxNVo2odRyaXUlgXdgGksG0VJ8JIePp8O9AxId35qPYLFl66bCRH8crY+2Oif4E8/GaOhaU5y5ejqRgsr2fsJakVG+2m5o7EbFXB47hZ67Os02hQBGKdpBBd1zvGGIYB1HcLUDLRbqW7qEvTXQu+E4LiCXK3ZyGGY0WMCDaFXwil4lCj5aFL7Uwsks7eT+f19wZjTYHg/BeRiQWSvysom5sJ5JEC9o0C2OneH+jWQIZFBNo+CaRVkEDyA1ir7Lr4z8TDDnpGahSkUrSo1Ab9n0z2e1Nvt+68aYvMIEZd0YYs0J/+QoUHTIjThFAXq/LTK1TblMz/NKvAfOVc4eNwTLcbAvaM6Pu8OiHUISxN0tPwVRXySSW0zOn9RoajOdXGHbAAnsc/dmd7L/3fsnhVQhKTrRUq81ctwHEFl6BtQ== ribeyre@uchicago.edu
EOM
      ) | while read -r line; do
        key=$(echo $line | awk '{ print $3 }')
        if ! grep "$key" .ssh/authorized_keys > /dev/null 2>&1; then
          echo $line >> .ssh/authorized_keys
        fi
      done
    else
      echo "$dir does not exist"
    fi
  done
)
  EOF
end

log "certbot certonly -a manual -i nginx -d '*.gen3workshop.org'" do
  level :info
end
