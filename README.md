# Tests unitaires du contrat "Voting"

Les 22 tests JS proposés couvrent l'ensemble des fonctions du contrat et en particulier :
 - le workflow
 - les cas d'erreur fonctionnels (vote multiple, vote pour une proposition inexistante, ...)
 - la logique de calcul du vainqueur (ici 3 votes pour la proposition 1)
 - les évènements

On vérifie aussi que seuls les utilisateurs autorisés peuvent appeler les fonctions du contrat.

la fonction `setupForStatus` permet d'établir un état minimum pour chaque fonction testée en fonction de l'avancement du workflow, tout en factorisant le code. 

