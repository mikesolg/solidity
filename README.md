# Tests unitaires du contrat "Voting"

Les 22 tests JS proposés couvrent l'ensemble des fonctions.
le workflow, la logique de calcul du vainqueur, les évenements.

On vérifie aussi que seuls les utilisateurs autorisés peuvent appeler les fonctions du contrat.

enfin on vérifie que le calcul de la proposition vainqueur est correct (3 votes pour la proposition 1).

la fonction setupForStatus permet d'établir un état minimum pour chaque fonction testée en fonction de l'avancement du workflow, tout en factorisant le code. 

