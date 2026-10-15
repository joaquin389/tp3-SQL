USE mediatheque;

DROP PROCEDURE IF EXISTS p_emprunter;
DROP PROCEDURE IF EXISTS p_rendre;
DROP PROCEDURE IF EXISTS p_bilan_adherent;

DELIMITER //

CREATE PROCEDURE p_emprunter(
  IN p_code_barre VARCHAR(40),
  IN p_adherent_id INT,
  OUT p_emprunt_id INT
)
SQL SECURITY DEFINER
BEGIN
  DECLARE v_adherent_trouve INT DEFAULT NULL;
  DECLARE v_actif TINYINT DEFAULT NULL;
  DECLARE v_exemplaire_id INT DEFAULT NULL;
  DECLARE v_disponible TINYINT DEFAULT NULL;
  DECLARE v_etat VARCHAR(40) DEFAULT NULL;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  SET p_emprunt_id = NULL;
  START TRANSACTION;

  SELECT id, actif
    INTO v_adherent_trouve, v_actif
    FROM adherent
   WHERE id = p_adherent_id
   FOR UPDATE;

  IF v_adherent_trouve IS NULL THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Adhérent introuvable.';
  END IF;

  IF COALESCE(v_actif, 0) <> 1 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Inscription inactive : l''adhérent ne peut pas emprunter.';
  END IF;

  SELECT id, disponible, etat
    INTO v_exemplaire_id, v_disponible, v_etat
    FROM exemplaire
   WHERE code_barre = p_code_barre
   FOR UPDATE;

  IF v_exemplaire_id IS NULL THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Code-barres inconnu.';
  END IF;

  IF v_etat = 'hors_service' THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Exemplaire hors service.';
  END IF;

  IF COALESCE(v_disponible, 0) <> 1 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Exemplaire déjà emprunté ou indisponible.';
  END IF;

  IF f_nb_emprunts_en_cours(p_adherent_id) >= 5 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Quota atteint : cinq emprunts en cours maximum.';
  END IF;

  IF f_penalites_dues(p_adherent_id) > 10.00 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Emprunt refusé : plus de 10,00 € de pénalités impayées.';
  END IF;

  INSERT INTO emprunt (exemplaire_id, adherent_id)
  VALUES (v_exemplaire_id, p_adherent_id);

  SET p_emprunt_id = LAST_INSERT_ID();
  COMMIT;
END//

CREATE PROCEDURE p_rendre(IN p_code_barre VARCHAR(40))
SQL SECURITY DEFINER
BEGIN
  DECLARE v_emprunt_id INT DEFAULT NULL;
  DECLARE v_adherent_id INT DEFAULT NULL;
  DECLARE v_date_retour_prevue DATE DEFAULT NULL;
  DECLARE v_jours_retard INT DEFAULT 0;
  DECLARE v_montant DECIMAL(10, 2) DEFAULT 0.00;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  SELECT em.id, em.adherent_id, em.date_retour_prevue
    INTO v_emprunt_id, v_adherent_id, v_date_retour_prevue
    FROM emprunt em
    JOIN exemplaire ex ON ex.id = em.exemplaire_id
   WHERE ex.code_barre = p_code_barre
     AND em.date_retour_reelle IS NULL
   ORDER BY em.id DESC
   LIMIT 1
   FOR UPDATE;

  IF v_emprunt_id IS NULL THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Aucun emprunt en cours pour cet exemplaire.';
  END IF;

  SET v_jours_retard = GREATEST(
    DATEDIFF(CURDATE(), v_date_retour_prevue),
    0
  );
  SET v_montant = ROUND(v_jours_retard * 0.20, 2);

  UPDATE emprunt
     SET date_retour_reelle = CURDATE()
   WHERE id = v_emprunt_id;

  IF v_jours_retard > 0 THEN
    INSERT INTO penalite (adherent_id, montant, motif, payee)
    VALUES (
      v_adherent_id,
      v_montant,
      CONCAT('Retard de ', v_jours_retard, ' jour(s)'),
      0
    );
  END IF;

  COMMIT;

  SELECT v_emprunt_id AS emprunt_id,
         v_jours_retard AS jours_de_retard,
         v_montant AS montant_facture;
END//

CREATE PROCEDURE p_bilan_adherent(IN p_adherent_id INT)
SQL SECURITY DEFINER
BEGIN
  SELECT a.*,
         f_nb_emprunts_en_cours(a.id) AS emprunts_en_cours,
         f_penalites_dues(a.id) AS penalites_dues
    FROM adherent a
   WHERE a.id = p_adherent_id;

  SELECT em.id AS emprunt_id,
         ex.code_barre,
         em.date_emprunt,
         em.date_retour_prevue,
         f_jours_de_retard(em.id) AS jours_de_retard
    FROM emprunt em
    JOIN exemplaire ex ON ex.id = em.exemplaire_id
   WHERE em.adherent_id = p_adherent_id
     AND em.date_retour_reelle IS NULL
   ORDER BY em.date_retour_prevue;

  SELECT COUNT(*) AS total_emprunts
    FROM emprunt
   WHERE adherent_id = p_adherent_id;
END//

DELIMITER ;
