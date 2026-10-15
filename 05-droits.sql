USE mediatheque;

-- Prérequis : le compte 'app_media'@'localhost' existe.
-- Les procédures SQL SECURITY DEFINER exécutent leurs requêtes avec les droits
-- du créateur, alors que l'application ne reçoit que le droit EXECUTE.
REVOKE INSERT, UPDATE ON mediatheque.emprunt FROM 'app_media'@'localhost';
GRANT EXECUTE ON PROCEDURE mediatheque.p_emprunter
  TO 'app_media'@'localhost';
GRANT EXECUTE ON PROCEDURE mediatheque.p_rendre
  TO 'app_media'@'localhost';

-- Connecté comme app_media : le CALL doit fonctionner, l'INSERT doit être refusé.
-- CALL mediatheque.p_emprunter('<code-barres>', <adherent_id>, @emprunt_id);
-- INSERT INTO mediatheque.emprunt (exemplaire_id, adherent_id)
-- VALUES (<exemplaire_id>, <adherent_id>);
