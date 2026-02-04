import boto3

# Région Stockholm
region = 'eu-north-1' 
ec2 = boto3.client('ec2', region_name=region)

def lambda_handler(event, context):
    print(f"--- ALERTE REÇUE : Recherche des instances du projet groupe 13 à {region} ---")
    
    # 1. Identifier les instances :
    # - Qui sont en cours d'exécution (running)
    # - ET qui ont le Tag "Project" = "Cible"
    instances = ec2.describe_instances(
        Filters=[
            {'Name': 'instance-state-name', 'Values': ['running']},
            {'Name': 'tag:Project', 'Values': ['Cible']} 
        ]
    )
    
    ids_to_stop = []
    
    for reservation in instances['Reservations']:
        for instance in reservation['Instances']:
            ids_to_stop.append(instance['InstanceId'])
    
    # 2. Action
    if len(ids_to_stop) > 0:
        print(f"Machines ciblées (Tag: Cible) : {ids_to_stop}")
        ec2.stop_instances(InstanceIds=ids_to_stop)
        return f"STOP {len(ids_to_stop)} instances"
    else:
        print("Aucune machine 'Cible' en cours d'exécution. Les autres sont intouchables.")
        return "Aucune action"