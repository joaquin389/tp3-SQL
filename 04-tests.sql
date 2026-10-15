USE mediatheque;

-- T1 : prêt valide. Conserver les valeurs avant de poursuivre.
SET @code_t1 = (
  SELECT code_barre
    FROM exemplaire
   WHERE disponible = 1
     AND etat <> 'hors_service'
   ORDER BY id
   LIMIT 1
);
SET @adherent_t1 = (
  SELECT a.id
    FROM adherent a
   WHERE a.actif = 1
     AND f_nb_emprunts_en_cours(a.id) = 0
     AND f_penalites_dues(a.id) <= 10.00
   ORDER BY a.id
   LIMIT 1
);
CALL p_emprunter(@code_t1, @adherent_t1, @id_t1);
SELECT @id_t1 AS emprunt_cree;
SELECT code_barre, disponible
  FROM exemplaire
 WHERE code_barre = @code_t1;
SELECT operation, cle, auteur, details
  FROM journal_action
 ORDER BY id DESC
 LIMIT 1;

-- T2 : à décommenter pour vérifier le refus.
-- SET @autre_adherent = (
--   SELECT a.id FROM adherent a
--    WHERE a.actif = 1 AND a.id <> @adherent_t1
--      AND f_nb_emprunts_en_cours(a.id) < 5
--      AND f_penalites_dues(a.id) <= 10.00
--    ORDER BY a.id LIMIT 1
-- );
-- CALL p_emprunter(@code_t1, @autre_adherent, @id_echec);
-- Erreur attendue : Exemplaire déjà emprunté ou indisponible.

-- T3 : sélectionner un adhérent inactif et un exemplaire disponible.
SET @code_t3 = (
  SELECT code_barre FROM exemplaire
   WHERE disponible = 1 AND etat <> 'hors_service'
   ORDER BY id LIMIT 1
);
SET @adherent_inactif = (
  SELECT id FROM adherent WHERE actif = 0 ORDER BY id LIMIT 1
);
-- CALL p_emprunter(@code_t3, @adherent_inactif, @id_echec);
-- Erreur attendue : Inscription inactive : l'adhérent ne peut pas emprunter.

-- T4 : code-barres inconnu.
-- CALL p_emprunter('MED-99999', 1, @id_echec);
-- Erreur attendue : Code-barres inconnu.

-- T5 : cinq prêts, puis sixième refus. Il faut cinq exemplaires disponibles.
SET @adherent_quota = (
  SELECT a.id FROM adherent a
   WHERE a.actif = 1
     AND f_nb_emprunts_en_cours(a.id) = 0
     AND f_penalites_dues(a.id) <= 10.00
   ORDER BY a.id LIMIT 1
);
SET @code_quota = (
  SELECT code_barre FROM exemplaire
   WHERE disponible = 1 AND etat <> 'hors_service'
   ORDER BY id LIMIT 1
);
CALL p_emprunter(@code_quota, @adherent_quota, @id_quota_1);
SET @code_quota = (
  SELECT code_barre FROM exemplaire
   WHERE disponible = 1 AND etat <> 'hors_service'
   ORDER BY id LIMIT 1
);
CALL p_emprunter(@code_quota, @adherent_quota, @id_quota_2);
SET @code_quota = (
  SELECT code_barre FROM exemplaire
   WHERE disponible = 1 AND etat <> 'hors_service'
   ORDER BY id LIMIT 1
);
CALL p_emprunter(@code_quota, @adherent_quota, @id_quota_3);
SET @code_quota = (
  SELECT code_barre FROM exemplaire
   WHERE disponible = 1 AND etat <> 'hors_service'
   ORDER BY id LIMIT 1
);
CALL p_emprunter(@code_quota, @adherent_quota, @id_quota_4);
SET @code_quota = (
  SELECT code_barre FROM exemplaire
   WHERE disponible = 1 AND etat <> 'hors_service'
   ORDER BY id LIMIT 1
);
CALL p_emprunter(@code_quota, @adherent_quota, @id_quota_5);
SET @code_quota = (
  SELECT code_barre FROM exemplaire
   WHERE disponible = 1 AND etat <> 'hors_service'
   ORDER BY id LIMIT 1
);
-- CALL p_emprunter(@code_quota, @adherent_quota, @id_echec);
-- Erreur attendue : Quota atteint : cinq emprunts en cours maximum.

-- T6 : sélectionner un mauvais payeur et un exemplaire disponible.
SET @code_t6 = (
  SELECT code_barre FROM exemplaire
   WHERE disponible = 1 AND etat <> 'hors_service'
   ORDER BY id LIMIT 1
);
SET @mauvais_payeur = (
  SELECT adherent_id
    FROM penalite
   WHERE payee = 0
   GROUP BY adherent_id
  HAVING SUM(montant) > 10
   ORDER BY adherent_id
   LIMIT 1
);
-- CALL p_emprunter(@code_t6, @mauvais_payeur, @id_echec);
-- Erreur attendue : Emprunt refusé : plus de 10,00 € de pénalités impayées.

-- T7 : INSERT direct, sans procédure. Ne pas remplacer VALUES par INSERT...SELECT :
-- le trigger met à jour exemplaire, ce qui est interdit si la requête le lit aussi.
SET @code_t7 = (
  SELECT code_barre FROM exemplaire
   WHERE disponible = 1 AND etat <> 'hors_service'
   ORDER BY id LIMIT 1
);
SET @exemplaire_t7 = (
  SELECT id FROM exemplaire WHERE code_barre = @code_t7
);
INSERT INTO emprunt (
  exemplaire_id, adherent_id, date_emprunt, date_retour_prevue
)
VALUES (@exemplaire_t7, 2, NULL, NULL);
SELECT em.id, em.date_emprunt, em.date_retour_prevue,
       ex.code_barre, ex.disponible
  FROM emprunt em
  JOIN exemplaire ex ON ex.id = em.exemplaire_id
 WHERE em.id = LAST_INSERT_ID();

-- T8 : préparer un emprunt en retard avec un INSERT direct, puis le rendre.
SET @code_t8 = (
  SELECT code_barre FROM exemplaire
   WHERE disponible = 1 AND etat <> 'hors_service'
   ORDER BY id LIMIT 1
);
SET @exemplaire_t8 = (
  SELECT id FROM exemplaire WHERE code_barre = @code_t8
);
INSERT INTO emprunt (
  exemplaire_id, adherent_id, date_emprunt, date_retour_prevue
)
VALUES (
  @exemplaire_t8, @adherent_t1,
  DATE_SUB(CURDATE(), INTERVAL 20 DAY),
  DATE_SUB(CURDATE(), INTERVAL 6 DAY)
);
CALL p_rendre(@code_t8);
SELECT code_barre, disponible
  FROM exemplaire
 WHERE code_barre = @code_t8;
SELECT adherent_id, montant, motif
  FROM penalite
 ORDER BY id DESC
 LIMIT 1;

-- T9 : le retour précédent a fermé le seul emprunt de ce code.
-- CALL p_rendre(@code_t8);
-- Erreur attendue : Aucun emprunt en cours pour cet exemplaire.
