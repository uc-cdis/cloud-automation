#Automatically generated from a corresponding variables.tf on 2022-07-12 10:48:11.054601

#The type of cluster that the jobs are running in. kube-aws is deprecated, so it should mostly be EKS clusters
#Acceptable values are: "EKS", "kube-aws"
cluster_type = "EKS"

#The email addresses that notifications from this instance should be sent to
emails = ["someone@uchicago.edu","otherone@uchicago.edu"]

#The subject of the emails sent to the addresses enumerated previously
topic_display = "cronjob manitor"

