-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: May 11, 2026 at 11:56 PM
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `mediscan_db`
--

DELIMITER $$
--
-- Procedures
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `GetMedicineInfo` (IN `med_name` VARCHAR(150))   BEGIN
    SELECT 
        medicine_name,
        generic_name,
        uses,
        dosage_adult,
        side_effects,
        interactions,
        contraindications
    FROM medicine_info
    WHERE medicine_name LIKE CONCAT('%', med_name, '%')
       OR generic_name LIKE CONCAT('%', med_name, '%')
    LIMIT 1;
    
    IF ROW_COUNT() = 0 THEN
        SELECT alternative_name, reason 
        FROM medicine_alternatives 
        WHERE medicine_name LIKE CONCAT('%', med_name, '%');
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `GetNearestPharmacies` (IN `user_lat` DECIMAL(10,8), IN `user_lng` DECIMAL(11,8), IN `medicine` VARCHAR(150))   BEGIN
    SELECT 
        p.pharmacy_id,
        p.name,
        p.address,
        p.phone,
        p.rating,
        p.delivery_available,
        mi.price,
        mi.stock_quantity,
        (6371 * ACOS(COS(RADIANS(user_lat)) * COS(RADIANS(p.latitude)) * 
        COS(RADIANS(p.longitude) - RADIANS(user_lng)) + 
        SIN(RADIANS(user_lat)) * SIN(RADIANS(p.latitude)))) AS distance_km
    FROM pharmacies p
    JOIN medicine_inventory mi ON p.pharmacy_id = mi.pharmacy_id
    WHERE mi.medicine_name LIKE CONCAT('%', medicine, '%') 
      AND mi.stock_quantity > 0
      AND mi.expiry_date > CURDATE()
    ORDER BY distance_km
    LIMIT 10;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `GetUserReservations` (IN `uid` INT)   BEGIN
    SELECT 
        r.reservation_id,
        p.name AS pharmacy_name,
        pm.medicine_name,
        r.status,
        r.reserved_until,
        r.created_at
    FROM reservations r
    JOIN pharmacies p ON r.pharmacy_id = p.pharmacy_id
    JOIN prescription_medicines pm ON r.prescription_medicine_id = pm.id
    WHERE r.user_id = uid
    ORDER BY r.created_at DESC;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `delivery_orders`
--

CREATE TABLE `delivery_orders` (
  `order_id` char(36) NOT NULL DEFAULT uuid(),
  `user_id` char(36) NOT NULL,
  `pharmacy_id` char(36) NOT NULL,
  `delivery_person_id` char(36) DEFAULT NULL,
  `status` enum('assigned','picked_up','in_transit','delivered') DEFAULT 'assigned',
  `tracking_location` point DEFAULT NULL,
  `payment_status` enum('pending','paid','refunded') DEFAULT 'pending',
  `discount` decimal(10,2) DEFAULT NULL,
  `Quantity` int(11) DEFAULT NULL,
  `Total price` decimal(10,0) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `family_profiles`
--

CREATE TABLE `family_profiles` (
  `family_id` char(36) NOT NULL DEFAULT uuid(),
  `parent_user_id` char(36) NOT NULL,
  `member_name` varchar(100) NOT NULL,
  `relation` varchar(50) NOT NULL,
  `date_of_birth` date DEFAULT NULL,
  `medical_conditions` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `family_profiles`
--

INSERT INTO `family_profiles` (`family_id`, `parent_user_id`, `member_name`, `relation`, `date_of_birth`, `medical_conditions`) VALUES
('7e6ac454-3cc1-11f1-b1ec-70089427b150', '1', 'Mary Doe', 'Mother', '1965-03-15', 'Hypertension'),
('7e6b0867-3cc1-11f1-b1ec-70089427b150', '1', 'James Doe', 'Brother', '2010-07-22', 'Asthma'),
('8d06f1e4-3cc1-11f1-b1ec-70089427b150', '1', 'Mary Doe', 'Mother', '1965-03-15', 'Hypertension'),
('8d07114c-3cc1-11f1-b1ec-70089427b150', '1', 'James Doe', 'Brother', '2010-07-22', 'Asthma');

-- --------------------------------------------------------

--
-- Stand-in structure for view `low_stock_alert_view`
-- (See below for the actual view)
--
CREATE TABLE `low_stock_alert_view` (
`pharmacy_name` varchar(150)
,`medicine_name` varchar(150)
,`stock_quantity` int(11)
,`expiry_date` date
);

-- --------------------------------------------------------

--
-- Table structure for table `medicine_alternatives`
--

CREATE TABLE `medicine_alternatives` (
  `id` char(36) NOT NULL DEFAULT uuid(),
  `medicine_name` varchar(150) NOT NULL,
  `alternative_name` varchar(150) NOT NULL,
  `reason` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `medicine_alternatives`
--

INSERT INTO `medicine_alternatives` (`id`, `medicine_name`, `alternative_name`, `reason`) VALUES
('53075fb6-3ccb-11f1-b1ec-70089427b150', 'Albuterol Inhaler', 'ProAir Inhaler', 'Same active ingredient - Salbutamol'),
('53076016-3ccb-11f1-b1ec-70089427b150', 'Ciprofloxacin 500mg', 'Ciprobay 500mg', 'Same active ingredient - Ciprofloxacin'),
('53076075-3ccb-11f1-b1ec-70089427b150', 'Ciprofloxacin 500mg', 'Ciplox 500mg', 'Same active ingredient - Ciprofloxacin'),
('530760d8-3ccb-11f1-b1ec-70089427b150', 'Doxycycline 100mg', 'Vibramycin 100mg', 'Same active ingredient - Doxycycline'),
('53076141-3ccb-11f1-b1ec-70089427b150', 'Doxycycline 100mg', 'Doryx 100mg', 'Same active ingredient - Doxycycline'),
('530761a2-3ccb-11f1-b1ec-70089427b150', 'Furosemide 40mg', 'Lasix 40mg', 'Same active ingredient - Furosemide'),
('5307620a-3ccb-11f1-b1ec-70089427b150', 'Furosemide 40mg', 'Frusol 40mg', 'Same active ingredient - Furosemide'),
('53076265-3ccb-11f1-b1ec-70089427b150', 'Warfarin 5mg', 'Coumadin 5mg', 'Same active ingredient - Warfarin'),
('530762cc-3ccb-11f1-b1ec-70089427b150', 'Warfarin 5mg', 'Jantoven 5mg', 'Same active ingredient - Warfarin'),
('53076333-3ccb-11f1-b1ec-70089427b150', 'Clopidogrel 75mg', 'Plavix 75mg', 'Same active ingredient - Clopidogrel'),
('53076395-3ccb-11f1-b1ec-70089427b150', 'Clopidogrel 75mg', 'Iscover 75mg', 'Same active ingredient - Clopidogrel'),
('7e70a1e0-3cc1-11f1-b1ec-70089427b150', 'Panadol 500mg', 'Tylenol 500mg', 'Same active ingredient'),
('7e70a5ae-3cc1-11f1-b1ec-70089427b150', 'Panadol 500mg', 'Adol 500mg', 'Same active ingredient'),
('7e70a6a7-3cc1-11f1-b1ec-70089427b150', 'Brufen 400mg', 'Advil 400mg', 'Same composition'),
('7e70a701-3cc1-11f1-b1ec-70089427b150', 'Amoxicillin 500mg', 'Moxilen 500mg', 'Same active ingredient'),
('837cf251-3cdb-11f1-b1ec-70089427b150', 'Panadol Extra 500mg', 'Paracetamol 500mg + Caffeine', 'Same composition - different brand'),
('837d101a-3cdb-11f1-b1ec-70089427b150', 'Panadol Extra 500mg', 'Febridol Extra', 'Same active ingredients'),
('837d111a-3cdb-11f1-b1ec-70089427b150', 'Mortal 400mg', 'Brufen 400mg', 'Same active ingredient - Ibuprofen'),
('837d118f-3cdb-11f1-b1ec-70089427b150', 'Mortal 400mg', 'Advil 400mg', 'Same active ingredient - Ibuprofen'),
('837d1273-3cdb-11f1-b1ec-70089427b150', 'Amoxil 500mg', 'Moxilen 500mg', 'Same active ingredient - Amoxicillin'),
('837d12e2-3cdb-11f1-b1ec-70089427b150', 'Amoxil 500mg', 'Biomox 500mg', 'Same active ingredient - Amoxicillin'),
('837d1364-3cdb-11f1-b1ec-70089427b150', 'Catafast 50mg', 'Voltaren Rapid 50mg', 'Same active ingredient - Diclofenac Potassium'),
('837d13d5-3cdb-11f1-b1ec-70089427b150', 'Catafast 50mg', 'Dicloran 50mg', 'Same active ingredient - Diclofenac Potassium'),
('837d143e-3cdb-11f1-b1ec-70089427b150', 'Flagyl 500mg', 'Metronidazole 500mg', 'Same active ingredient'),
('837d14a2-3cdb-11f1-b1ec-70089427b150', 'Flagyl 500mg', 'Amrizole 500mg', 'Same active ingredient - Metronidazole'),
('837d1507-3cdb-11f1-b1ec-70089427b150', 'Zithromax 500mg', 'Azomax 500mg', 'Same active ingredient - Azithromycin'),
('837d1568-3cdb-11f1-b1ec-70089427b150', 'Zithromax 500mg', 'Zomax 500mg', 'Same active ingredient - Azithromycin'),
('837d15cf-3cdb-11f1-b1ec-70089427b150', 'Ciprinol 500mg', 'Cipro 500mg', 'Same active ingredient - Ciprofloxacin'),
('837d1631-3cdb-11f1-b1ec-70089427b150', 'Ciprinol 500mg', 'Quinsair 500mg', 'Same active ingredient - Ciprofloxacin'),
('837d1699-3cdb-11f1-b1ec-70089427b150', 'Glucophage 500mg', 'Metfomin 500mg', 'Same active ingredient - Metformin'),
('837d16f8-3cdb-11f1-b1ec-70089427b150', 'Glucophage 500mg', 'Cidophage 500mg', 'Same active ingredient - Metformin'),
('837d175f-3cdb-11f1-b1ec-70089427b150', 'Antinal 400mg', 'Nifuroxazide 400mg', 'Same active ingredient'),
('837d17bc-3cdb-11f1-b1ec-70089427b150', 'Antinal 400mg', 'Nifurantel 400mg', 'Same active ingredient - Nifuroxazide'),
('837d1821-3cdb-11f1-b1ec-70089427b150', 'Zyrtec 10mg', 'Cetrine 10mg', 'Same active ingredient - Cetirizine'),
('837d1884-3cdb-11f1-b1ec-70089427b150', 'Zyrtec 10mg', 'Allercet 10mg', 'Same active ingredient - Cetirizine'),
('837d18ed-3cdb-11f1-b1ec-70089427b150', 'Claritin 10mg', 'Lorastine 10mg', 'Same active ingredient - Loratadine'),
('837d194e-3cdb-11f1-b1ec-70089427b150', 'Claritin 10mg', 'Lorano 10mg', 'Same active ingredient - Loratadine'),
('837d19b1-3cdb-11f1-b1ec-70089427b150', 'Telfast 180mg', 'Fexodine 180mg', 'Same active ingredient - Fexofenadine'),
('837d1a0d-3cdb-11f1-b1ec-70089427b150', 'Telfast 180mg', 'Allerfex 180mg', 'Same active ingredient - Fexofenadine'),
('837d1a73-3cdb-11f1-b1ec-70089427b150', 'Ventolin Inhaler', 'Butalin Inhaler', 'Same active ingredient - Salbutamol'),
('837d1ad1-3cdb-11f1-b1ec-70089427b150', 'Ventolin Inhaler', 'Asthalin Inhaler', 'Same active ingredient - Salbutamol'),
('837d1b34-3cdb-11f1-b1ec-70089427b150', 'Singulair 10mg', 'Monteka 10mg', 'Same active ingredient - Montelukast'),
('837d1b93-3cdb-11f1-b1ec-70089427b150', 'Singulair 10mg', 'Lukasm 10mg', 'Same active ingredient - Montelukast'),
('837d1bfd-3cdb-11f1-b1ec-70089427b150', 'Buscopan 10mg', 'Spasmoblock 10mg', 'Same active ingredient - Hyoscine Butylbromide'),
('837d1c5d-3cdb-11f1-b1ec-70089427b150', 'Buscopan 10mg', 'Butylscopolamine 10mg', 'Same active ingredient'),
('837d1cbf-3cdb-11f1-b1ec-70089427b150', 'Spasmex 20mg', 'Mebeverine 20mg', 'Same active ingredient'),
('837d1d1d-3cdb-11f1-b1ec-70089427b150', 'Spasmex 20mg', 'Colofac 20mg', 'Same active ingredient - Mebeverine'),
('837d1d84-3cdb-11f1-b1ec-70089427b150', 'Solmucol 600mg', 'Acc 600mg', 'Same active ingredient - Acetylcysteine'),
('837d1de6-3cdb-11f1-b1ec-70089427b150', 'Solmucol 600mg', 'Mucomyst 600mg', 'Same active ingredient - Acetylcysteine'),
('837d1e49-3cdb-11f1-b1ec-70089427b150', 'Bisolvon 8mg', 'Bromhexine 8mg', 'Same active ingredient'),
('837d1eaf-3cdb-11f1-b1ec-70089427b150', 'Bisolvon 8mg', 'Phlemex 8mg', 'Same active ingredient - Bromhexine'),
('8d0ac305-3cc1-11f1-b1ec-70089427b150', 'Panadol 500mg', 'Tylenol 500mg', 'Same active ingredient'),
('8d0adee7-3cc1-11f1-b1ec-70089427b150', 'Panadol 500mg', 'Adol 500mg', 'Same active ingredient'),
('8d0adfc6-3cc1-11f1-b1ec-70089427b150', 'Brufen 400mg', 'Advil 400mg', 'Same composition'),
('8d0ae00a-3cc1-11f1-b1ec-70089427b150', 'Amoxicillin 500mg', 'Moxilen 500mg', 'Same active ingredient');

-- --------------------------------------------------------

--
-- Table structure for table `medicine_info`
--

CREATE TABLE `medicine_info` (
  `id` int(11) NOT NULL,
  `medicine_name` varchar(150) NOT NULL,
  `generic_name` varchar(150) DEFAULT NULL,
  `uses` text DEFAULT NULL,
  `dosage_adult` text DEFAULT NULL,
  `dosage_child` text DEFAULT NULL,
  `side_effects` text DEFAULT NULL,
  `interactions` text DEFAULT NULL,
  `contraindications` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `medicine_info`
--

INSERT INTO `medicine_info` (`id`, `medicine_name`, `generic_name`, `uses`, `dosage_adult`, `dosage_child`, `side_effects`, `interactions`, `contraindications`) VALUES
(1, 'Paracetamol', 'Acetaminophen', 'Pain reliever and fever reducer', '500mg - 1000mg every 4-6 hours. Max 4000mg/day', NULL, 'Nausea, rash, liver damage (overdose)', 'Warfarin, alcohol, carbamazepine', NULL),
(2, 'Ibuprofen', 'Ibuprofen', 'Pain relief, anti-inflammatory, fever reducer', '200mg - 400mg every 6-8 hours. Max 1200mg/day OTC', NULL, 'Stomach pain, heartburn, ulcer', 'Aspirin, blood thinners, lithium', NULL),
(3, 'Amoxicillin', 'Amoxicillin', 'Antibiotic for bacterial infections', '250mg - 500mg every 8 hours for 7-14 days', NULL, 'Diarrhea, rash, nausea', 'Methotrexate, warfarin, oral contraceptives', NULL),
(4, 'Ventolin', 'Salbutamol', 'Bronchodilator for asthma treatment', 'Inhaler: 1-2 puffs every 4-6 hours as needed', NULL, 'Tremor, rapid heartbeat, headache', 'Beta-blockers, diuretics', NULL),
(9, 'Paracetamol 500mg', 'Acetaminophen', 'Pain relief, fever reduction', '500-1000mg every 4-6h, max 4000mg/day', '10-15mg/kg every 4-6h', 'Nausea, rash, liver damage', 'Warfarin, alcohol', 'Severe liver disease'),
(10, 'Ibuprofen 400mg', 'Ibuprofen', 'Pain, inflammation, fever', '200-400mg every 6-8h, max 1200mg/day', '5-10mg/kg every 6-8h', 'Stomach pain, ulcer, heartburn', 'Aspirin, blood thinners', 'Stomach ulcer, kidney disease'),
(11, 'Amoxicillin 500mg', 'Amoxicillin', 'Bacterial infections', '250-500mg every 8h for 7-14 days', '20-40mg/kg/day divided', 'Diarrhea, rash, nausea', 'Methotrexate, warfarin', 'Penicillin allergy'),
(12, 'Azithromycin 500mg', 'Azithromycin', 'Respiratory infections', '500mg day 1, then 250mg days 2-5', '10mg/kg day 1, then 5mg/kg', 'Nausea, diarrhea, abdominal pain', 'Antacids, warfarin', 'Liver disease'),
(13, 'Ciprofloxacin 500mg', 'Ciprofloxacin', 'Urinary tract, respiratory infections', '250-500mg every 12h', 'Not recommended under 18', 'Nausea, diarrhea, tendon rupture', 'Theophylline, warfarin', 'Under 18, tendon issues'),
(14, 'Doxycycline 100mg', 'Doxycycline', 'Bacterial infections, acne, malaria', '100mg every 12h day 1, then 100mg daily', '2mg/kg day 1, then 1mg/kg', 'Photosensitivity, nausea, esophagitis', 'Antacids, isotretinoin', 'Pregnancy, children under 8'),
(15, 'Metformin 500mg', 'Metformin', 'Type 2 diabetes', '500mg twice daily with meals', 'Not for children', 'Nausea, diarrhea, metallic taste', 'Alcohol, contrast dye', 'Kidney disease, liver disease'),
(16, 'Omeprazole 20mg', 'Omeprazole', 'GERD, heartburn, ulcers', '20mg once daily before meal', '10-20mg daily', 'Headache, nausea, vitamin B12 deficiency', 'Clopidogrel, digoxin', 'Liver disease'),
(17, 'Lisinopril 10mg', 'Lisinopril', 'High blood pressure, heart failure', '10-40mg once daily', 'Not recommended', 'Cough, dizziness, angioedema', 'Diuretics, NSAIDs', 'Pregnancy, angioedema history'),
(18, 'Amlodipine 5mg', 'Amlodipine', 'High blood pressure, angina', '5-10mg once daily', 'Not recommended', 'Swelling ankles, dizziness, flushing', 'Grapefruit, simvastatin', 'Liver disease'),
(19, 'Atorvastatin 20mg', 'Atorvastatin', 'High cholesterol', '10-80mg once daily', 'Not recommended', 'Muscle pain, liver enzyme elevation', 'Grapefruit, warfarin', 'Liver disease, pregnancy'),
(20, 'Losartan 50mg', 'Losartan', 'High blood pressure', '50mg once daily', 'Not recommended', 'Dizziness, fatigue, hyperkalemia', 'Lithium, diuretics', 'Pregnancy, liver disease'),
(21, 'Gabapentin 300mg', 'Gabapentin', 'Neuropathic pain, seizures', '300-600mg 3 times daily', '10-15mg/kg/day', 'Dizziness, drowsiness, edema', 'Antacids, morphine', 'Kidney disease'),
(22, 'Tramadol 50mg', 'Tramadol', 'Moderate to severe pain', '50-100mg every 4-6h, max 400mg/day', 'Not recommended under 12', 'Nausea, dizziness, seizures', 'SSRIs, MAOIs, alcohol', 'Seizure disorder, addiction risk'),
(23, 'Cetirizine 10mg', 'Cetirizine', 'Allergies, hay fever', '10mg once daily', '5mg once daily', 'Drowsiness, dry mouth, headache', 'Alcohol, sedatives', 'Kidney disease'),
(24, 'Loratadine 10mg', 'Loratadine', 'Allergies', '10mg once daily', '5mg once daily', 'Headache, dry mouth', 'None significant', 'Liver disease'),
(25, 'Fexofenadine 180mg', 'Fexofenadine', 'Allergies', '180mg once daily', '30-60mg twice daily', 'Headache, nausea', 'Fruit juices, antacids', 'Kidney disease'),
(26, 'Prednisolone 5mg', 'Prednisolone', 'Inflammation, autoimmune', '5-60mg daily as prescribed', '1-2mg/kg/day', 'Weight gain, mood changes, osteoporosis', 'NSAIDs, insulin', 'Systemic fungal infection'),
(27, 'Dexamethasone 4mg', 'Dexamethasone', 'Inflammation, COVID-19', '4-8mg daily', '0.15mg/kg/day', 'Insomnia, weight gain, hyperglycemia', 'NSAIDs, warfarin', 'Systemic fungal infection'),
(28, 'Hydrochlorothiazide 25mg', 'HCTZ', 'High blood pressure, edema', '12.5-25mg once daily', 'Not recommended', 'Low potassium, dizziness, sun sensitivity', 'Lithium, digoxin', 'Sulfa allergy, anuria'),
(29, 'Furosemide 40mg', 'Furosemide', 'Edema, heart failure', '20-80mg daily', '1-2mg/kg daily', 'Low potassium, dehydration, tinnitus', 'Aminoglycosides, lithium', 'Anuria, sulfa allergy'),
(30, 'Spironolactone 25mg', 'Spironolactone', 'Heart failure, acne, edema', '25-100mg daily', '1-3mg/kg/day', 'Hyperkalemia, gynecomastia', 'ACE inhibitors, potassium', 'Kidney disease, hyperkalemia'),
(31, 'Warfarin 5mg', 'Warfarin', 'Blood thinner, stroke prevention', '2-10mg daily adjusted by INR', 'Not recommended', 'Bleeding, bruising, necrosis', 'Many: aspirin, antibiotics, vitamin K', 'Pregnancy, bleeding disorder'),
(32, 'Aspirin 81mg', 'Aspirin', 'Pain, fever, heart attack prevention', '81-325mg daily', '10-15mg/kg every 4-6h', 'Stomach bleeding, ringing in ears', 'Warfarin, ibuprofen', 'Reye syndrome in children, ulcer'),
(33, 'Clopidogrel 75mg', 'Clopidogrel', 'Stroke, heart attack prevention', '75mg once daily', 'Not recommended', 'Bleeding, bruising', 'Omeprazole, warfarin', 'Active bleeding'),
(34, 'Digoxin 0.25mg', 'Digoxin', 'Heart failure, atrial fibrillation', '0.125-0.25mg daily', '5-10mcg/kg/day', 'Nausea, vision changes, arrhythmias', 'Amiodarone, verapamil', 'Heart block, ventricular tachycardia'),
(35, 'Levothyroxine 100mcg', 'Levothyroxine', 'Hypothyroidism', '50-200mcg daily', '2-3mcg/kg daily', 'Weight loss, palpitations, insomnia', 'Calcium, iron', 'Untreated adrenal insufficiency'),
(36, 'Insulin Aspart', 'Insulin Aspart', 'Diabetes mellitus', 'Individualized dosing', 'Individualized dosing', 'Hypoglycemia, weight gain', 'Oral hypoglycemics', 'Hypoglycemia'),
(37, 'Metronidazole 500mg', 'Metronidazole', 'Bacterial, parasitic infections', '500mg twice daily for 7 days', '15-30mg/kg/day', 'Metallic taste, nausea, disulfiram reaction', 'Alcohol, warfarin', 'Alcohol consumption'),
(38, 'Fluconazole 150mg', 'Fluconazole', 'Yeast infections', '150mg once', '3-6mg/kg once', 'Headache, nausea, liver toxicity', 'Warfarin, phenytoin', 'Pregnancy, liver disease'),
(39, 'Acyclovir 400mg', 'Acyclovir', 'Herpes, chickenpox', '400mg 3 times daily for 7-10 days', '20mg/kg 4 times daily', 'Nausea, diarrhea, headache', 'Probenecid', 'Kidney disease'),
(40, 'Clindamycin 300mg', 'Clindamycin', 'Bacterial infections', '300mg every 8h', '10-20mg/kg/day', 'Diarrhea, C. difficile colitis', 'Erythromycin', 'Antibiotic-associated colitis'),
(41, 'Cephalexin 500mg', 'Cephalexin', 'Bacterial infections', '500mg every 8h', '25-50mg/kg/day', 'Diarrhea, rash, nausea', 'Metformin', 'Penicillin allergy (caution)'),
(42, 'Nitrofurantoin 100mg', 'Nitrofurantoin', 'UTI', '100mg twice daily for 5-7 days', '5-7mg/kg/day', 'Nausea, brown urine', 'Antacids', 'Kidney disease, under 1 month'),
(43, 'Albuterol Inhaler', 'Salbutamol', 'Asthma, COPD', '1-2 puffs every 4-6h', '1-2 puffs every 4-6h', 'Tremor, palpitations, headache', 'Beta-blockers', 'Tachycardia'),
(44, 'Fluticasone Inhaler', 'Fluticasone', 'Asthma maintenance', '1-2 puffs twice daily', '1-2 puffs twice daily', 'Thrush, hoarseness', 'Ritonavir', 'Status asthmaticus'),
(45, 'Montelukast 10mg', 'Montelukast', 'Asthma, allergies', '10mg once daily at night', '4-5mg once daily', 'Headache, mood changes', 'Phenobarbital', 'Phenylketonuria'),
(46, 'Esomeprazole 40mg', 'Esomeprazole', 'GERD, ulcers', '20-40mg once daily', '10-20mg daily', 'Headache, diarrhea', 'Clopidogrel', 'Liver disease'),
(47, 'Pantoprazole 40mg', 'Pantoprazole', 'GERD, ulcers', '40mg once daily', '20mg daily', 'Headache, nausea', 'Warfarin, methotrexate', 'Liver disease'),
(48, 'Ranitidine 150mg', 'Ranitidine', 'GERD, ulcers', '150mg twice daily', '2-4mg/kg twice daily', 'Headache, constipation', 'Warfarin', 'Porphyria'),
(49, 'Panadol Extra 500mg', 'Paracetamol + Caffeine', 'Pain relief, fever reduction', '1-2 tablets every 6h, max 8/day', 'Not under 12', 'Nausea, rash, liver damage', 'Warfarin, alcohol', 'Severe liver disease'),
(50, 'Panadol Cold & Flu', 'Paracetamol + Pseudoephedrine', 'Cold, flu, sinus congestion', '2 tablets every 6h', 'Not under 12', 'Drowsiness, dry mouth', 'MAOIs, antidepressants', 'High blood pressure'),
(51, 'Catafast 50mg', 'Diclofenac Potassium', 'Acute pain, dental pain', '1-2 tablets, then 1 tablet every 4-6h', 'Not under 14', 'Stomach pain, ulcer', 'Aspirin, blood thinners', 'Stomach ulcer, asthma'),
(52, 'Voltaren 75mg', 'Diclofenac Sodium', 'Muscle pain, arthritis', '1 tablet daily', 'Not for children', 'Heartburn, dizziness', 'Lithium, methotrexate', 'Heart disease'),
(53, 'Mortal 400mg', 'Ibuprofen', 'Pain, inflammation, fever', '1 tablet every 8h', '5-10mg/kg', 'Stomach pain, ulcer', 'Aspirin, warfarin', 'Kidney disease'),
(54, 'Brufen 600mg', 'Ibuprofen', 'Arthritis, pain', '1 tablet every 12h', 'Not for children', 'Nausea, headache', 'ACE inhibitors', 'Peptic ulcer'),
(55, 'Amoxil 500mg', 'Amoxicillin', 'Bacterial infections', '1 tablet every 8h', '20-40mg/kg/day', 'Diarrhea, rash', 'Methotrexate', 'Penicillin allergy'),
(56, 'Augmentin 1g', 'Amoxicillin + Clavulanic acid', 'Bacterial infections', '1 tablet every 12h', '25-45mg/kg/day', 'Diarrhea, nausea', 'Allopurinol', 'Penicillin allergy'),
(57, 'Ciprinol 500mg', 'Ciprofloxacin', 'UTI, respiratory infections', '1 tablet every 12h', 'Not under 18', 'Nausea, tendonitis', 'Theophylline', 'Under 18'),
(58, 'Zithromax 500mg', 'Azithromycin', 'Respiratory infections', '1 tablet daily for 3 days', '10mg/kg day 1', 'Abdominal pain', 'Antacids', 'Liver disease'),
(59, 'Flagyl 500mg', 'Metronidazole', 'Bacterial, parasitic infections', '1 tablet every 8h', '15-30mg/kg/day', 'Metallic taste', 'Alcohol, warfarin', 'Alcohol consumption'),
(60, 'Rocephin 1g', 'Ceftriaxone', 'Severe bacterial infections', '1g daily IM/IV', '50-75mg/kg/day', 'Diarrhea, rash', 'Calcium', 'Newborn hyperbilirubinemia'),
(61, 'Tavanic 500mg', 'Levofloxacin', 'Pneumonia, sinusitis, UTI', '1 tablet daily', 'Not under 18', 'Dizziness, tendon rupture', 'NSAIDs', 'Epilepsy'),
(62, 'Cravit 500mg', 'Levofloxacin', 'Respiratory, UTI', '1 tablet daily', 'Not under 18', 'Insomnia, headache', 'Warfarin', 'Under 18'),
(63, 'Glucophage 500mg', 'Metformin', 'Type 2 diabetes', '1 tablet twice daily with meals', 'Not for children', 'Nausea, diarrhea', 'Alcohol, contrast dye', 'Kidney disease'),
(64, 'Glucophage XR 750mg', 'Metformin Extended Release', 'Type 2 diabetes', '1-2 tablets daily', 'Not for children', 'GI upset', 'Cimetidine', 'Lactic acidosis'),
(65, 'Diamicron 60mg', 'Gliclazide', 'Type 2 diabetes', '1-2 tablets daily', 'Not for children', 'Hypoglycemia', 'Sulfonamides', 'Type 1 diabetes'),
(66, 'Januvia 100mg', 'Sitagliptin', 'Type 2 diabetes', '1 tablet daily', 'Not for children', 'Headache, pancreatitis', 'NSAIDs', 'Type 1 diabetes'),
(67, 'Antinal 400mg', 'Nifuroxazide', 'Acute diarrhea', '1 capsule every 6h', '5-10mg/kg/day', 'No significant', 'None', 'Under 1 month'),
(68, 'Entocid', 'Bismuth Subsalicylate', 'Diarrhea, indigestion', '2 tablets every 6h', 'Not under 12', 'Dark tongue/stool', 'Anticoagulants', 'Reye syndrome'),
(69, 'Spasmex 20mg', 'Mebeverine', 'IBS, abdominal cramps', '1 tablet 3 times daily', 'Not for children', 'Dizziness, rash', 'None significant', 'Paralytic ileus'),
(70, 'Buscopan 10mg', 'Hyoscine Butylbromide', 'Abdominal cramps', '1-2 tablets every 8h', 'Not under 6', 'Dry mouth, blurred vision', 'Antihistamines', 'Glaucoma'),
(71, 'Miconazole Cream', 'Miconazole', 'Fungal infections', 'Apply twice daily', 'Apply twice daily', 'Burning, itching', 'None', 'Hypersensitivity'),
(72, 'Canesten Cream', 'Clotrimazole', 'Fungal infections', 'Apply twice daily', 'Apply twice daily', 'Redness, irritation', 'None', 'Hypersensitivity'),
(73, 'Fucicort Cream', 'Fusidic Acid + Betamethasone', 'Infected eczema', 'Apply 3 times daily', 'Apply 3 times daily', 'Skin atrophy', 'None', 'Viral skin lesions'),
(74, 'Kenacort Injection', 'Triamcinolone', 'Severe inflammation', '40-80mg IM', 'Not recommended', 'Weight gain, mood changes', 'NSAIDs', 'Systemic infection'),
(75, 'Depo-Medrol Injection', 'Methylprednisolone', 'Inflammation, allergic reactions', '40-120mg IM', '1-2mg/kg', 'Insomnia, hyperglycemia', 'NSAIDs', 'Fungal infection'),
(76, 'Hydrocortisone Cream 1%', 'Hydrocortisone', 'Skin inflammation, itching', 'Apply 2-3 times daily', 'Apply 2-3 times daily', 'Skin thinning', 'None', 'Bacterial infection'),
(77, 'Ebastel 10mg', 'Ebastine', 'Allergies, hay fever', '1 tablet daily', 'Not under 12', 'Drowsiness, dry mouth', 'Ketoconazole', 'Liver disease'),
(78, 'Telfast 180mg', 'Fexofenadine', 'Allergies, chronic urticaria', '1 tablet daily', '30-60mg twice daily', 'Headache, nausea', 'Fruit juices', 'Kidney disease'),
(79, 'Zyrtec 10mg', 'Cetirizine', 'Allergies, hay fever', '1 tablet daily', '5mg daily', 'Drowsiness', 'Alcohol, sedatives', 'Kidney disease'),
(80, 'Claritin 10mg', 'Loratadine', 'Allergies', '1 tablet daily', '5mg daily', 'Headache, dry mouth', 'None significant', 'Liver disease'),
(81, 'Rhinathiol 200mg', 'Carbocisteine', 'Chest congestion', '1 capsule every 8h', '20mg/kg/day', 'GI upset', 'None', 'Peptic ulcer'),
(82, 'Solmucol 600mg', 'Acetylcysteine', 'Mucus thinner', '1 effervescent tablet daily', '100-200mg twice daily', 'Nausea', 'Nitroglycerin', 'Asthma'),
(83, 'Bisolvon 8mg', 'Bromhexine', 'Chest congestion', '1-2 tablets 3 times daily', '4-8mg 3 times daily', 'Nausea, diarrhea', 'None', 'Peptic ulcer'),
(84, 'Ventolin Inhaler', 'Salbutamol', 'Asthma, COPD', '1-2 puffs every 4-6h', '1-2 puffs every 4-6h', 'Tremor, palpitations', 'Beta-blockers', 'Tachycardia'),
(85, 'Seretide Inhaler', 'Fluticasone + Salmeterol', 'Asthma maintenance', '1-2 puffs twice daily', '1-2 puffs twice daily', 'Thrush, hoarseness', 'Ritonavir', 'Status asthmaticus'),
(86, 'Singulair 10mg', 'Montelukast', 'Asthma, allergies', '1 tablet daily at night', '4-5mg daily', 'Headache, mood changes', 'Phenobarbital', 'Phenylketonuria'),
(87, 'Avamys Nasal Spray', 'Fluticasone Furoate', 'Allergic rhinitis', '2 sprays each nostril daily', '1 spray each nostril daily', 'Nasal irritation', 'None', 'Nasal infection'),
(88, 'Otrivin Nasal Spray', 'Xylometazoline', 'Nasal congestion', '2 sprays each nostril every 8-10h', '1 spray each nostril every 8-10h', 'Burning, dryness', 'MAOIs', 'Glaucoma');

-- --------------------------------------------------------

--
-- Table structure for table `medicine_inventory`
--

CREATE TABLE `medicine_inventory` (
  `inventory_id` char(36) NOT NULL DEFAULT uuid(),
  `pharmacy_id` char(36) NOT NULL,
  `medicine_name` varchar(150) NOT NULL,
  `generic_name` varchar(150) DEFAULT NULL,
  `batch_number` varchar(100) DEFAULT NULL,
  `expiry_date` date NOT NULL,
  `stock_quantity` int(11) DEFAULT 0,
  `price` decimal(10,2) DEFAULT NULL,
  `is_prescription_required` tinyint(1) DEFAULT 1,
  `last_updated` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `medicine_inventory`
--

INSERT INTO `medicine_inventory` (`inventory_id`, `pharmacy_id`, `medicine_name`, `generic_name`, `batch_number`, `expiry_date`, `stock_quantity`, `price`, `is_prescription_required`, `last_updated`) VALUES
('20fbf439-3ccb-11f1-b1ec-70089427b150', '1', 'Paracetamol 500mg', 'Acetaminophen', 'BAN2024001', '2025-12-31', 500, 5.99, 1, '2026-04-20 15:10:55'),
('20fc7262-3ccb-11f1-b1ec-70089427b150', '1', 'Ibuprofen 400mg', 'Ibuprofen', 'BRU2024001', '2025-11-30', 300, 7.50, 1, '2026-04-20 15:10:55'),
('20fc750b-3ccb-11f1-b1ec-70089427b150', '1', 'Amoxicillin 500mg', 'Amoxicillin', 'AMO2024001', '2025-10-15', 150, 12.00, 1, '2026-04-20 15:10:55'),
('20fc7640-3ccb-11f1-b1ec-70089427b150', '1', 'Azithromycin 500mg', 'Azithromycin', 'AZI2024001', '2025-09-20', 80, 25.00, 1, '2026-04-20 15:10:55'),
('20fc7721-3ccb-11f1-b1ec-70089427b150', '1', 'Cetirizine 10mg', 'Cetirizine', 'CET2024001', '2026-01-15', 400, 4.50, 1, '2026-04-20 15:10:55'),
('20ff7d05-3ccb-11f1-b1ec-70089427b150', '2', 'Paracetamol 500mg', 'Acetaminophen', 'BAN2024002', '2025-12-31', 800, 5.50, 1, '2026-04-20 15:10:55'),
('20ff90ef-3ccb-11f1-b1ec-70089427b150', '2', 'Metformin 500mg', 'Metformin', 'MET2024001', '2025-08-30', 200, 8.00, 1, '2026-04-20 15:10:55'),
('20ff9249-3ccb-11f1-b1ec-70089427b150', '2', 'Lisinopril 10mg', 'Lisinopril', 'LIS2024001', '2025-10-10', 180, 10.00, 1, '2026-04-20 15:10:55'),
('20ff9391-3ccb-11f1-b1ec-70089427b150', '2', 'Albuterol Inhaler', 'Salbutamol', 'ALB2024001', '2025-07-15', 60, 35.00, 1, '2026-04-20 15:10:55'),
('20ff94b0-3ccb-11f1-b1ec-70089427b150', '2', 'Omeprazole 20mg', 'Omeprazole', 'OME2024001', '2026-02-28', 350, 6.50, 1, '2026-04-20 15:10:55'),
('2102da5d-3ccb-11f1-b1ec-70089427b150', '3', 'Amoxicillin 500mg', 'Amoxicillin', 'AMO2024002', '2025-11-20', 120, 13.00, 1, '2026-04-20 15:10:55'),
('2102f976-3ccb-11f1-b1ec-70089427b150', '3', 'Ciprofloxacin 500mg', 'Ciprofloxacin', 'CIP2024001', '2025-09-25', 75, 18.00, 1, '2026-04-20 15:10:55'),
('2102fbd1-3ccb-11f1-b1ec-70089427b150', '3', 'Doxycycline 100mg', 'Doxycycline', 'DOX2024001', '2025-12-05', 90, 22.00, 1, '2026-04-20 15:10:55'),
('2102fd83-3ccb-11f1-b1ec-70089427b150', '3', 'Loratadine 10mg', 'Loratadine', 'LOR2024001', '2026-01-10', 250, 4.00, 1, '2026-04-20 15:10:55'),
('508e8583-3cdb-11f1-b1ec-70089427b150', '1', 'Panadol Extra 500mg', 'Paracetamol + Caffeine', 'PEX24001', '2025-12-31', 450, 12.00, 1, '2026-04-20 17:06:46'),
('508f30ec-3cdb-11f1-b1ec-70089427b150', '1', 'Mortal 400mg', 'Ibuprofen', 'MOR24002', '2025-11-15', 320, 8.00, 1, '2026-04-20 17:06:46'),
('508f36f8-3cdb-11f1-b1ec-70089427b150', '1', 'Amoxil 500mg', 'Amoxicillin', 'AMX24003', '2025-10-20', 180, 15.00, 1, '2026-04-20 17:06:46'),
('508f39b4-3cdb-11f1-b1ec-70089427b150', '1', 'Antinal 400mg', 'Nifuroxazide', 'ANT24004', '2025-12-10', 250, 9.00, 1, '2026-04-20 17:06:46'),
('50938d04-3cdb-11f1-b1ec-70089427b150', '2', 'Panadol Extra 500mg', 'Paracetamol + Caffeine', 'PEX24005', '2026-01-31', 850, 11.50, 1, '2026-04-20 17:06:46'),
('5093b248-3cdb-11f1-b1ec-70089427b150', '2', 'Augmentin 1g', 'Amoxicillin + Clavulanic acid', 'AUG24006', '2025-09-30', 120, 45.00, 1, '2026-04-20 17:06:46'),
('50942a3b-3cdb-11f1-b1ec-70089427b150', '2', 'Flagyl 500mg', 'Metronidazole', 'FLG24007', '2025-12-05', 200, 8.00, 1, '2026-04-20 17:06:46'),
('509430c3-3cdb-11f1-b1ec-70089427b150', '2', 'Ventolin Inhaler', 'Salbutamol', 'VEN24008', '2025-08-15', 80, 55.00, 1, '2026-04-20 17:06:46'),
('5094339c-3cdb-11f1-b1ec-70089427b150', '2', 'Zyrtec 10mg', 'Cetirizine', 'ZYR24009', '2026-02-28', 350, 7.50, 1, '2026-04-20 17:06:46'),
('50963f3d-3cdb-11f1-b1ec-70089427b150', '3', 'Catafast 50mg', 'Diclofenac Potassium', 'CAT24010', '2025-12-15', 200, 12.00, 1, '2026-04-20 17:06:46'),
('5096579c-3cdb-11f1-b1ec-70089427b150', '3', 'Zithromax 500mg', 'Azithromycin', 'ZIT24011', '2025-11-10', 95, 38.00, 1, '2026-04-20 17:06:46'),
('509659cf-3cdb-11f1-b1ec-70089427b150', '3', 'Glucophage 500mg', 'Metformin', 'GLU24012', '2026-01-20', 220, 7.50, 1, '2026-04-20 17:06:46'),
('50965af2-3cdb-11f1-b1ec-70089427b150', '3', 'Telfast 180mg', 'Fexofenadine', 'TEL24013', '2025-12-28', 160, 22.00, 1, '2026-04-20 17:06:46'),
('50965bff-3cdb-11f1-b1ec-70089427b150', '3', 'Buscopan 10mg', 'Hyoscine Butylbromide', 'BUS24014', '2026-03-15', 180, 6.00, 1, '2026-04-20 17:06:46'),
('50986ba4-3cdb-11f1-b1ec-70089427b150', '4', 'Panadol Cold & Flu', 'Paracetamol + Pseudoephedrine', 'PCF24015', '2025-12-20', 150, 15.00, 1, '2026-04-20 17:06:46'),
('5098733a-3cdb-11f1-b1ec-70089427b150', '4', 'Voltaren 75mg', 'Diclofenac Sodium', 'VOL24016', '2026-01-05', 130, 10.00, 1, '2026-04-20 17:06:46'),
('5098748a-3cdb-11f1-b1ec-70089427b150', '4', 'Brufen 600mg', 'Ibuprofen', 'BRU24017', '2025-11-25', 100, 12.00, 1, '2026-04-20 17:06:46'),
('5098757e-3cdb-11f1-b1ec-70089427b150', '4', 'Spasmex 20mg', 'Mebeverine', 'SPA24018', '2025-12-18', 90, 18.00, 1, '2026-04-20 17:06:46'),
('509c04e9-3cdb-11f1-b1ec-70089427b150', '5', 'Ciprinol 500mg', 'Ciprofloxacin', 'CIP24019', '2025-10-12', 85, 18.00, 1, '2026-04-20 17:06:46'),
('509c1f65-3cdb-11f1-b1ec-70089427b150', '5', 'Diamicron 60mg', 'Gliclazide', 'DIA24020', '2026-02-01', 110, 30.00, 1, '2026-04-20 17:06:46'),
('509c2219-3cdb-11f1-b1ec-70089427b150', '5', 'Ebastel 10mg', 'Ebastine', 'EBA24021', '2025-12-08', 140, 14.00, 1, '2026-04-20 17:06:46'),
('509c2450-3cdb-11f1-b1ec-70089427b150', '5', 'Solmucol 600mg', 'Acetylcysteine', 'SOL24022', '2025-11-28', 170, 9.00, 1, '2026-04-20 17:06:46'),
('509e144f-3cdb-11f1-b1ec-70089427b150', '6', 'Tavanic 500mg', 'Levofloxacin', 'TAV24023', '2025-09-20', 50, 45.00, 1, '2026-04-20 17:06:46'),
('509e1ed0-3cdb-11f1-b1ec-70089427b150', '6', 'Cravit 500mg', 'Levofloxacin', 'CRA24024', '2025-10-05', 45, 44.00, 1, '2026-04-20 17:06:46'),
('509e2152-3cdb-11f1-b1ec-70089427b150', '6', 'Januvia 100mg', 'Sitagliptin', 'JAN24025', '2026-01-15', 35, 95.00, 1, '2026-04-20 17:06:46'),
('509e232f-3cdb-11f1-b1ec-70089427b150', '6', 'Claritin 10mg', 'Loratadine', 'CLA24026', '2026-03-01', 120, 6.50, 1, '2026-04-20 17:06:46'),
('50a06bb7-3cdb-11f1-b1ec-70089427b150', '7', 'Glucophage XR 750mg', 'Metformin Extended Release', 'GLX24027', '2026-02-10', 95, 18.00, 1, '2026-04-20 17:06:46'),
('50a084d5-3cdb-11f1-b1ec-70089427b150', '7', 'Singulair 10mg', 'Montelukast', 'SIN24028', '2025-12-22', 70, 32.00, 1, '2026-04-20 17:06:46'),
('50a087ab-3cdb-11f1-b1ec-70089427b150', '7', 'Seretide Inhaler', 'Fluticasone + Salmeterol', 'SER24029', '2025-09-18', 40, 85.00, 1, '2026-04-20 17:06:46'),
('50a089d4-3cdb-11f1-b1ec-70089427b150', '7', 'Avamys Nasal Spray', 'Fluticasone Furoate', 'AVA24030', '2026-01-25', 60, 45.00, 1, '2026-04-20 17:06:46'),
('50a25111-3cdb-11f1-b1ec-70089427b150', '8', 'Rocephin 1g', 'Ceftriaxone', 'ROC24031', '2025-11-15', 200, 65.00, 1, '2026-04-20 17:06:46'),
('50a26787-3cdb-11f1-b1ec-70089427b150', '8', 'Entocid', 'Bismuth Subsalicylate', 'ENT24032', '2026-01-10', 300, 5.00, 1, '2026-04-20 17:06:46'),
('50a270e9-3cdb-11f1-b1ec-70089427b150', '8', 'Rhinathiol 200mg', 'Carbocisteine', 'RHI24033', '2025-12-05', 150, 8.00, 1, '2026-04-20 17:06:46'),
('50a27308-3cdb-11f1-b1ec-70089427b150', '8', 'Bisolvon 8mg', 'Bromhexine', 'BIS24034', '2026-02-20', 200, 4.50, 1, '2026-04-20 17:06:46'),
('50a43a85-3cdb-11f1-b1ec-70089427b150', '9', 'Panadol Extra 500mg', 'Paracetamol + Caffeine', 'PEX24035', '2026-01-31', 400, 12.00, 1, '2026-04-20 17:06:47'),
('50a45174-3cdb-11f1-b1ec-70089427b150', '9', 'Amoxil 500mg', 'Amoxicillin', 'AMX24036', '2025-11-20', 130, 15.00, 1, '2026-04-20 17:06:47'),
('50a45291-3cdb-11f1-b1ec-70089427b150', '9', 'Mortal 400mg', 'Ibuprofen', 'MOR24037', '2025-12-15', 250, 8.00, 1, '2026-04-20 17:06:47'),
('50a45366-3cdb-11f1-b1ec-70089427b150', '9', 'Flagyl 500mg', 'Metronidazole', 'FLG24038', '2025-12-20', 140, 8.00, 1, '2026-04-20 17:06:47'),
('50a60bde-3cdb-11f1-b1ec-70089427b150', '10', 'Catafast 50mg', 'Diclofenac Potassium', 'CAT24039', '2026-01-10', 180, 12.00, 1, '2026-04-20 17:06:47'),
('50a61e06-3cdb-11f1-b1ec-70089427b150', '10', 'Zithromax 500mg', 'Azithromycin', 'ZIT24040', '2025-10-25', 70, 38.00, 1, '2026-04-20 17:06:47'),
('50a61f2b-3cdb-11f1-b1ec-70089427b150', '10', 'Ventolin Inhaler', 'Salbutamol', 'VEN24041', '2025-09-05', 55, 55.00, 1, '2026-04-20 17:06:47'),
('50a61ffa-3cdb-11f1-b1ec-70089427b150', '10', 'Zyrtec 10mg', 'Cetirizine', 'ZYR24042', '2026-02-28', 280, 7.50, 1, '2026-04-20 17:06:47'),
('50a8b572-3cdb-11f1-b1ec-70089427b150', '11', 'Panadol Cold & Flu', 'Paracetamol + Pseudoephedrine', 'PCF24043', '2025-12-25', 120, 15.00, 1, '2026-04-20 17:06:47'),
('50a8d3c3-3cdb-11f1-b1ec-70089427b150', '11', 'Antinal 400mg', 'Nifuroxazide', 'ANT24044', '2026-01-05', 200, 9.00, 1, '2026-04-20 17:06:47'),
('50a8d4fc-3cdb-11f1-b1ec-70089427b150', '11', 'Spasmex 20mg', 'Mebeverine', 'SPA24045', '2025-12-28', 80, 18.00, 1, '2026-04-20 17:06:47'),
('50a8d5e0-3cdb-11f1-b1ec-70089427b150', '11', 'Buscopan 10mg', 'Hyoscine Butylbromide', 'BUS24046', '2026-03-20', 150, 6.00, 1, '2026-04-20 17:06:47'),
('50ac0256-3cdb-11f1-b1ec-70089427b150', '12', 'Voltaren 75mg', 'Diclofenac Sodium', 'VOL24047', '2026-01-15', 100, 10.00, 1, '2026-04-20 17:06:47'),
('50ac1ded-3cdb-11f1-b1ec-70089427b150', '12', 'Ciprinol 500mg', 'Ciprofloxacin', 'CIP24048', '2025-10-18', 60, 18.00, 1, '2026-04-20 17:06:47'),
('50ac20bd-3cdb-11f1-b1ec-70089427b150', '12', 'Telfast 180mg', 'Fexofenadine', 'TEL24049', '2025-12-30', 110, 22.00, 1, '2026-04-20 17:06:47'),
('50ac22d8-3cdb-11f1-b1ec-70089427b150', '12', 'Solmucol 600mg', 'Acetylcysteine', 'SOL24050', '2025-11-20', 130, 9.00, 1, '2026-04-20 17:06:47'),
('50adf55a-3cdb-11f1-b1ec-70089427b150', '13', 'Augmentin 1g', 'Amoxicillin + Clavulanic acid', 'AUG24051', '2025-10-10', 85, 45.00, 1, '2026-04-20 17:06:47'),
('50ae0c50-3cdb-11f1-b1ec-70089427b150', '13', 'Glucophage 500mg', 'Metformin', 'GLU24052', '2026-02-01', 180, 7.50, 1, '2026-04-20 17:06:47'),
('50ae0e29-3cdb-11f1-b1ec-70089427b150', '13', 'Diamicron 60mg', 'Gliclazide', 'DIA24053', '2026-02-15', 70, 30.00, 1, '2026-04-20 17:06:47'),
('50ae0f85-3cdb-11f1-b1ec-70089427b150', '13', 'Claritin 10mg', 'Loratadine', 'CLA24054', '2026-03-10', 140, 6.50, 1, '2026-04-20 17:06:47'),
('50b0a98a-3cdb-11f1-b1ec-70089427b150', '14', 'Panadol Extra 500mg', 'Paracetamol + Caffeine', 'PEX24055', '2026-01-31', 600, 11.50, 1, '2026-04-20 17:06:47'),
('50b0c48f-3cdb-11f1-b1ec-70089427b150', '14', 'Singulair 10mg', 'Montelukast', 'SIN24056', '2025-12-25', 55, 32.00, 1, '2026-04-20 17:06:47'),
('50b0c5a8-3cdb-11f1-b1ec-70089427b150', '14', 'Seretide Inhaler', 'Fluticasone + Salmeterol', 'SER24057', '2025-09-22', 35, 85.00, 1, '2026-04-20 17:06:47'),
('50b0c67c-3cdb-11f1-b1ec-70089427b150', '14', 'Avamys Nasal Spray', 'Fluticasone Furoate', 'AVA24058', '2026-01-30', 50, 45.00, 1, '2026-04-20 17:06:47'),
('50b0c734-3cdb-11f1-b1ec-70089427b150', '14', 'Ebastel 10mg', 'Ebastine', 'EBA24059', '2025-12-18', 120, 14.00, 1, '2026-04-20 17:06:47'),
('50b2a252-3cdb-11f1-b1ec-70089427b150', '15', 'Brufen 600mg', 'Ibuprofen', 'BRU24060', '2025-12-05', 90, 12.00, 1, '2026-04-20 17:06:47'),
('50b2c03b-3cdb-11f1-b1ec-70089427b150', '15', 'Januvia 100mg', 'Sitagliptin', 'JAN24061', '2026-01-20', 25, 95.00, 1, '2026-04-20 17:06:47'),
('50b2c1f3-3cdb-11f1-b1ec-70089427b150', '15', 'Entocid', 'Bismuth Subsalicylate', 'ENT24062', '2026-01-15', 220, 5.00, 1, '2026-04-20 17:06:47'),
('50b2c2ee-3cdb-11f1-b1ec-70089427b150', '15', 'Rhinathiol 200mg', 'Carbocisteine', 'RHI24063', '2025-12-10', 110, 8.00, 1, '2026-04-20 17:06:47'),
('50b4a4a0-3cdb-11f1-b1ec-70089427b150', '16', 'Tavanic 500mg', 'Levofloxacin', 'TAV24064', '2025-09-25', 40, 45.00, 1, '2026-04-20 17:06:47'),
('50b4ba7c-3cdb-11f1-b1ec-70089427b150', '16', 'Cravit 500mg', 'Levofloxacin', 'CRA24065', '2025-10-08', 35, 44.00, 1, '2026-04-20 17:06:47'),
('50b4be11-3cdb-11f1-b1ec-70089427b150', '16', 'Glucophage XR 750mg', 'Metformin Extended Release', 'GLX24066', '2026-02-15', 70, 18.00, 1, '2026-04-20 17:06:47'),
('50b4bf66-3cdb-11f1-b1ec-70089427b150', '16', 'Bisolvon 8mg', 'Bromhexine', 'BIS24067', '2026-02-28', 160, 4.50, 1, '2026-04-20 17:06:47'),
('50b68516-3cdb-11f1-b1ec-70089427b150', '17', 'Flagyl 500mg', 'Metronidazole', 'FLG24068', '2025-12-25', 120, 8.00, 1, '2026-04-20 17:06:47'),
('50b698a5-3cdb-11f1-b1ec-70089427b150', '17', 'Amoxil 500mg', 'Amoxicillin', 'AMX24069', '2025-11-15', 100, 15.00, 1, '2026-04-20 17:06:47'),
('50b699ed-3cdb-11f1-b1ec-70089427b150', '17', 'Panadol Extra 500mg', 'Paracetamol + Caffeine', 'PEX24070', '2025-12-31', 250, 12.00, 1, '2026-04-20 17:06:47'),
('50b69acc-3cdb-11f1-b1ec-70089427b150', '17', 'Zyrtec 10mg', 'Cetirizine', 'ZYR24071', '2026-02-20', 180, 7.50, 1, '2026-04-20 17:06:47'),
('50b89bbf-3cdb-11f1-b1ec-70089427b150', '18', 'Zithromax 500mg', 'Azithromycin', 'ZIT24072', '2025-11-05', 80, 38.00, 1, '2026-04-20 17:06:47'),
('50b8aa01-3cdb-11f1-b1ec-70089427b150', '18', 'Catafast 50mg', 'Diclofenac Potassium', 'CAT24073', '2026-01-20', 160, 12.00, 1, '2026-04-20 17:06:47'),
('50b8acc8-3cdb-11f1-b1ec-70089427b150', '18', 'Mortal 400mg', 'Ibuprofen', 'MOR24074', '2025-12-20', 280, 8.00, 1, '2026-04-20 17:06:47'),
('50b8d0bb-3cdb-11f1-b1ec-70089427b150', '18', 'Ventolin Inhaler', 'Salbutamol', 'VEN24075', '2025-09-10', 60, 55.00, 1, '2026-04-20 17:06:47'),
('50baaa1c-3cdb-11f1-b1ec-70089427b150', '19', 'Augmentin 1g', 'Amoxicillin + Clavulanic acid', 'AUG24076', '2025-10-15', 90, 45.00, 1, '2026-04-20 17:06:47'),
('50bac71e-3cdb-11f1-b1ec-70089427b150', '19', 'Glucophage 500mg', 'Metformin', 'GLU24077', '2026-02-05', 200, 7.50, 1, '2026-04-20 17:06:47'),
('50bacb4a-3cdb-11f1-b1ec-70089427b150', '19', 'Spasmex 20mg', 'Mebeverine', 'SPA24078', '2026-01-10', 85, 18.00, 1, '2026-04-20 17:06:47'),
('50bacd15-3cdb-11f1-b1ec-70089427b150', '19', 'Telfast 180mg', 'Fexofenadine', 'TEL24079', '2025-12-28', 130, 22.00, 1, '2026-04-20 17:06:47'),
('50bc82b6-3cdb-11f1-b1ec-70089427b150', '20', 'Panadol Extra 500mg', 'Paracetamol + Caffeine', 'PEX24080', '2026-01-31', 500, 12.00, 1, '2026-04-20 17:06:47'),
('50bc9c6f-3cdb-11f1-b1ec-70089427b150', '20', 'Singulair 10mg', 'Montelukast', 'SIN24081', '2026-01-15', 60, 32.00, 1, '2026-04-20 17:06:47'),
('50bc9da3-3cdb-11f1-b1ec-70089427b150', '20', 'Seretide Inhaler', 'Fluticasone + Salmeterol', 'SER24082', '2025-09-28', 40, 85.00, 1, '2026-04-20 17:06:47'),
('50bc9e75-3cdb-11f1-b1ec-70089427b150', '20', 'Antinal 400mg', 'Nifuroxazide', 'ANT24083', '2026-01-08', 220, 9.00, 1, '2026-04-20 17:06:47'),
('50bc9f27-3cdb-11f1-b1ec-70089427b150', '20', 'Buscopan 10mg', 'Hyoscine Butylbromide', 'BUS24084', '2026-03-25', 170, 6.00, 1, '2026-04-20 17:06:47'),
('7e6df231-3cc1-11f1-b1ec-70089427b150', '1', 'Panadol 500mg', 'Paracetamol', 'PAN2024001', '2025-12-31', 500, 8.50, 1, '2026-04-20 14:01:57'),
('7e6df667-3cc1-11f1-b1ec-70089427b150', '1', 'Amoxicillin 500mg', 'Amoxicillin', 'AMO2024002', '2025-10-15', 200, 25.00, 1, '2026-04-20 14:01:57'),
('7e6df79e-3cc1-11f1-b1ec-70089427b150', '1', 'Brufen 400mg', 'Ibuprofen', 'BRU2024003', '2025-11-20', 150, 15.00, 1, '2026-04-20 14:01:57'),
('7e6df834-3cc1-11f1-b1ec-70089427b150', '2', 'Panadol 500mg', 'Paracetamol', 'PAN2024010', '2025-12-31', 800, 8.00, 1, '2026-04-20 14:01:57'),
('7e6df8b3-3cc1-11f1-b1ec-70089427b150', '2', 'Zinacef 500mg', 'Cephalexin', 'ZIN2024011', '2025-09-30', 100, 35.00, 1, '2026-04-20 14:01:57'),
('7e6df92c-3cc1-11f1-b1ec-70089427b150', '2', 'Ventolin Inhaler', 'Salbutamol', 'VEN2024012', '2025-08-15', 50, 45.00, 1, '2026-04-20 14:01:57'),
('7e6df9a3-3cc1-11f1-b1ec-70089427b150', '3', 'Panadol 500mg', 'Paracetamol', 'PAN2024020', '2025-11-30', 50, 9.00, 1, '2026-04-20 14:01:57'),
('8d089479-3cc1-11f1-b1ec-70089427b150', '1', 'Panadol 500mg', 'Paracetamol', 'PAN2024001', '2025-12-31', 500, 8.50, 1, '2026-04-20 14:02:21'),
('8d08b8b0-3cc1-11f1-b1ec-70089427b150', '1', 'Amoxicillin 500mg', 'Amoxicillin', 'AMO2024002', '2025-10-15', 200, 25.00, 1, '2026-04-20 14:02:21'),
('8d08bd6f-3cc1-11f1-b1ec-70089427b150', '1', 'Brufen 400mg', 'Ibuprofen', 'BRU2024003', '2025-11-20', 150, 15.00, 1, '2026-04-20 14:02:21'),
('8d08c082-3cc1-11f1-b1ec-70089427b150', '2', 'Panadol 500mg', 'Paracetamol', 'PAN2024010', '2025-12-31', 800, 8.00, 1, '2026-04-20 14:02:21'),
('8d094d80-3cc1-11f1-b1ec-70089427b150', '2', 'Zinacef 500mg', 'Cephalexin', 'ZIN2024011', '2025-09-30', 100, 35.00, 1, '2026-04-20 14:02:21'),
('8d095263-3cc1-11f1-b1ec-70089427b150', '2', 'Ventolin Inhaler', 'Salbutamol', 'VEN2024012', '2025-08-15', 50, 45.00, 1, '2026-04-20 14:02:21'),
('8d09544c-3cc1-11f1-b1ec-70089427b150', '3', 'Panadol 500mg', 'Paracetamol', 'PAN2024020', '2025-11-30', 50, 9.00, 1, '2026-04-20 14:02:21'),
('c2af3dfe-dd5b-52c0-a10e-06a9221dcb57', '24', 'Paracetamol', 'Acetaminophen', 'BAT-177', '2027-02-20', 37, 14.85, 0, '2026-06-08 19:30:00'),
('a3756773-f7fe-503a-b573-4e038b8d2095', '24', 'Ibuprofen', 'Ibuprofen', 'BAT-177', '2027-02-20', 37, 21.78, 1, '2026-06-08 19:30:00'),
('448ee068-3715-59b3-ba41-ec00aa97c918', '24', 'Amoxicillin', 'Amoxicillin', 'BAT-177', '2027-02-20', 37, 34.65, 0, '2026-06-08 19:30:00'),
('28b5af7b-739a-5fff-b21e-6f6edf5868e6', '24', 'Ventolin', 'Salbutamol', 'BAT-177', '2027-02-20', 37, 32.67, 1, '2026-06-08 19:30:00'),
('1013881e-b273-5bf1-a87a-e31e149dbb48', '24', 'Paracetamol 500mg', 'Acetaminophen', 'BAT-177', '2027-02-20', 37, 17.82, 0, '2026-06-08 19:30:00'),
('e6a92881-cabf-5dbf-9f8b-6f1eb8e453f1', '24', 'Ibuprofen 400mg', 'Ibuprofen', 'BAT-177', '2027-02-20', 37, 25.74, 1, '2026-06-08 19:30:00'),
('ef2386c9-0b18-5883-88f9-9c3fc50a298a', '24', 'Amoxicillin 500mg', 'Amoxicillin (Penicillin Antibiotic)', 'BAT-177', '2027-02-20', 37, 41.58, 0, '2026-06-08 19:30:00'),
('82359f29-54ba-5029-ba7e-6e8142097d1e', '24', 'Azithromycin 500mg', 'Azithromycin', 'BAT-177', '2027-02-20', 37, 93.06, 0, '2026-06-08 19:30:00'),
('d1622b21-231f-5409-9cc1-9b228cc422d2', '24', 'Ciprofloxacin 500mg', 'Ciprofloxacin', 'BAT-177', '2027-02-20', 37, 49.50, 0, '2026-06-08 19:30:00'),
('2ded6ad6-8c1d-5dfd-b842-fc03b90ddf8c', '24', 'Doxycycline 100mg', 'Doxycycline', 'BAT-177', '2027-02-20', 37, 65.34, 1, '2026-06-08 19:30:00'),
('a5034c4c-5537-5b4d-b0ce-f8f3f679e8f0', '24', 'Metformin 500mg', 'Metformin', 'BAT-177', '2027-02-20', 37, 24.75, 0, '2026-06-08 19:30:00'),
('aea45f36-ded5-5495-8032-31bbf5e3e9aa', '24', 'Omeprazole 20mg', 'Omeprazole', 'BAT-177', '2027-02-20', 37, 99.99, 0, '2026-06-08 19:30:00'),
('3af6ec2a-0b82-58a9-9e91-fbb982050c2a', '24', 'Lisinopril 10mg', 'Lisinopril', 'BAT-177', '2027-02-20', 37, 73.26, 1, '2026-06-08 19:30:00'),
('ecebeb3f-15d8-592b-b2a8-1cafc195fb29', '24', 'Amlodipine 5mg', 'Amlodipine', 'BAT-177', '2027-02-20', 37, 109.89, 0, '2026-06-08 19:30:00'),
('fe912f9f-ecdf-5f4e-9c5e-00166a8ca9f9', '24', 'Atorvastatin 20mg', 'Atorvastatin', 'BAT-177', '2027-02-20', 37, 41.58, 0, '2026-06-08 19:30:00'),
('07071af3-ce55-513f-be4b-710172e2af31', '24', 'Losartan 50mg', 'Losartan', 'BAT-177', '2027-02-20', 37, 131.67, 0, '2026-06-08 19:30:00'),
('d795c9b8-f1ba-5686-9b98-da3239a9dcd4', '24', 'Gabapentin 300mg', 'Gabapentin', 'BAT-177', '2027-02-20', 37, 38.61, 1, '2026-06-08 19:30:00'),
('333f4b6c-6f81-5366-a647-33d5a22c4c80', '24', 'Tramadol 50mg', 'Tramadol', 'BAT-177', '2027-02-20', 37, 109.89, 1, '2026-06-08 19:30:00'),
('6ecadaa4-8651-5af3-af25-bdd520d2288f', '24', 'Cetirizine 10mg', 'Cetirizine', 'BAT-177', '2027-02-20', 37, 27.72, 0, '2026-06-08 19:30:00'),
('b596b027-f4f8-503b-8eb0-20759f931ef8', '24', 'Loratadine 10mg', 'Loratadine', 'BAT-177', '2027-02-20', 37, 37.62, 1, '2026-06-08 19:30:00'),
('e5643a1e-a160-5a12-91ba-72770bf9f4b7', '24', 'Fexofenadine 180mg', 'Fexofenadine', 'BAT-177', '2027-02-20', 37, 57.42, 0, '2026-06-08 19:30:00'),
('c7b38914-bf29-54b4-8088-b1ee1cbc9d71', '24', 'Prednisolone 5mg', 'Prednisolone', 'BAT-177', '2027-02-20', 37, 70.29, 0, '2026-06-08 19:30:00'),
('d753f317-7ae1-58e3-8a69-76f4c86e2b84', '24', 'Dexamethasone 4mg', 'Dexamethasone', 'BAT-177', '2027-02-20', 37, 91.08, 0, '2026-06-08 19:30:00'),
('624cd45c-5941-52e9-8403-33d66ac3c47b', '24', 'Hydrochlorothiazide 25mg', 'HCTZ', 'BAT-177', '2027-02-20', 37, 59.40, 1, '2026-06-08 19:30:00'),
('e735297f-b504-5192-8b93-bf89ad684cf9', '24', 'Furosemide 40mg', 'Furosemide', 'BAT-177', '2027-02-20', 37, 97.02, 0, '2026-06-08 19:30:00'),
('96e45dc9-aefb-5ea6-8031-f5b2fddea88a', '24', 'Spironolactone 25mg', 'Spironolactone', 'BAT-177', '2027-02-20', 37, 60.39, 1, '2026-06-08 19:30:00'),
('e4b880e7-6186-5530-be0a-99bca2896722', '24', 'Warfarin 5mg', 'Warfarin', 'BAT-177', '2027-02-20', 37, 24.75, 0, '2026-06-08 19:30:00'),
('6b72f6a9-4a87-5501-9882-f829d35f7bad', '24', 'Aspirin 81mg', 'Aspirin', 'BAT-177', '2027-02-20', 37, 11.88, 1, '2026-06-08 19:30:00'),
('aeccae15-747a-5310-9ecb-351e384d3890', '24', 'Clopidogrel 75mg', 'Clopidogrel', 'BAT-177', '2027-02-20', 37, 24.75, 0, '2026-06-08 19:30:00'),
('42ccb4d1-36af-59b3-b737-af4dc05c0cc7', '24', 'Digoxin 0.25mg', 'Digoxin', 'BAT-177', '2027-02-20', 37, 24.75, 0, '2026-06-08 19:30:00'),
('c34cfee3-03fc-5239-be45-fb6e6c8c5840', '24', 'Levothyroxine 100mcg', 'Levothyroxine', 'BAT-177', '2027-02-20', 37, 131.67, 0, '2026-06-08 19:30:00'),
('715c8c87-9692-5449-bd23-bdbeafb916a4', '24', 'Insulin Aspart', 'Insulin Aspart', 'BAT-177', '2027-02-20', 37, 36.63, 1, '2026-06-08 19:30:00'),
('e1816c94-9e47-56df-8b04-eda3f52ebb1c', '24', 'Metronidazole 500mg', 'Metronidazole', 'BAT-177', '2027-02-20', 37, 21.78, 1, '2026-06-08 19:30:00'),
('b75e26c3-f430-509f-91e7-a60d04536307', '24', 'Fluconazole 150mg', 'Fluconazole', 'BAT-177', '2027-02-20', 37, 144.54, 0, '2026-06-08 19:30:00'),
('ff5de03a-87dc-5413-8116-487a4b1c41e1', '24', 'Acyclovir 400mg', 'Acyclovir', 'BAT-177', '2027-02-20', 37, 18.81, 1, '2026-06-08 19:30:00'),
('66f1e87b-cd6b-5b48-9445-55d82dbaeacf', '24', 'Clindamycin 300mg', 'Clindamycin', 'BAT-177', '2027-02-20', 37, 25.74, 0, '2026-06-08 19:30:00'),
('872c052a-438d-5012-bea1-d81d521ffce2', '24', 'Cephalexin 500mg', 'Cephalexin', 'BAT-177', '2027-02-20', 37, 14.85, 1, '2026-06-08 19:30:00'),
('dcd51951-427d-51e8-8bca-6d75d441dd75', '24', 'Nitrofurantoin 100mg', 'Nitrofurantoin', 'BAT-177', '2027-02-20', 37, 35.64, 0, '2026-06-08 19:30:00'),
('2656c8ef-3ee0-59c6-a701-6c7502259cf2', '24', 'Albuterol Inhaler', 'Salbutamol', 'BAT-177', '2027-02-20', 37, 125.73, 1, '2026-06-08 19:30:00'),
('721ab5d4-eb8e-51dd-9562-21f972910ac5', '24', 'Fluticasone Inhaler', 'Fluticasone', 'BAT-177', '2027-02-20', 37, 146.52, 0, '2026-06-08 19:30:00'),
('cdfc1816-25b6-5da3-968b-75c3363d4f29', '24', 'Montelukast 10mg', 'Montelukast', 'BAT-177', '2027-02-20', 37, 43.56, 0, '2026-06-08 19:30:00'),
('6a8d5d1a-cf93-54bb-b48a-fab7e94250ba', '24', 'Esomeprazole 40mg', 'Esomeprazole', 'BAT-177', '2027-02-20', 37, 118.80, 1, '2026-06-08 19:30:00'),
('721581ce-306b-5b77-9baa-7ee64f2099e0', '24', 'Pantoprazole 40mg', 'Pantoprazole', 'BAT-177', '2027-02-20', 37, 23.76, 1, '2026-06-08 19:30:00'),
('2ce71f54-9487-51a8-8e8f-b00bdfd56c9e', '24', 'Ranitidine 150mg', 'Ranitidine', 'BAT-177', '2027-02-20', 37, 27.72, 0, '2026-06-08 19:30:00'),
('8c92db02-9c29-52e8-8040-72b7bd0d4c20', '24', 'Panadol Extra 500mg', 'Paracetamol + Caffeine', 'BAT-177', '2027-02-20', 37, 24.75, 1, '2026-06-08 19:30:00'),
('a5adc49d-f9be-5ae4-aaf5-0b2eac771e71', '24', 'Panadol Cold & Flu', 'Paracetamol + Pseudoephedrine', 'BAT-177', '2027-02-20', 37, 27.72, 1, '2026-06-08 19:30:00'),
('de154c59-cc2d-59bb-a341-fd61a7483d82', '24', 'Catafast 50mg', 'Diclofenac Potassium', 'BAT-177', '2027-02-20', 37, 37.62, 0, '2026-06-08 19:30:00'),
('65f03741-ec46-5e88-bbcf-dd07894e5a00', '24', 'Voltaren 75mg', 'Diclofenac Sodium', 'BAT-177', '2027-02-20', 37, 47.52, 0, '2026-06-08 19:30:00'),
('2740c633-d6ad-5994-99ba-513f6a8f820a', '24', 'Mortal 400mg', 'Ibuprofen', 'BAT-177', '2027-02-20', 37, 57.42, 0, '2026-06-08 19:30:00'),
('08743274-a052-5d60-ae7c-72789aee5e6f', '24', 'Brufen 600mg', 'Ibuprofen', 'BAT-177', '2027-02-20', 37, 31.68, 1, '2026-06-08 19:30:00'),
('1bdd0649-a896-5df9-b883-678aa5d82de3', '24', 'Amoxil 500mg', 'Amoxicillin', 'BAT-177', '2027-02-20', 37, 44.55, 0, '2026-06-08 19:30:00'),
('db75a8b7-d761-5ebd-b55f-24251972af9a', '24', 'Augmentin 1g', 'Amoxicillin + Clavulanic acid', 'BAT-177', '2027-02-20', 37, 94.05, 1, '2026-06-08 19:30:00'),
('9cef1130-5a9d-534e-9430-ae0edf766d60', '24', 'Ciprinol 500mg', 'Ciprofloxacin', 'BAT-177', '2027-02-20', 37, 126.72, 0, '2026-06-08 19:30:00'),
('794eba01-4241-55c6-bdf3-6cc0296e9e4f', '24', 'Zithromax 500mg', 'Azithromycin', 'BAT-177', '2027-02-20', 37, 114.84, 1, '2026-06-08 19:30:00'),
('307b690d-3d27-51df-9b76-5ce0fd3587d7', '24', 'Flagyl 500mg', 'Metronidazole', 'BAT-177', '2027-02-20', 37, 23.76, 0, '2026-06-08 19:30:00'),
('85397fbd-cdf5-5538-a1b2-51bc40945440', '24', 'Rocephin 1g', 'Ceftriaxone', 'BAT-177', '2027-02-20', 37, 117.81, 0, '2026-06-08 19:30:00'),
('826250c9-87ad-5e6e-8729-76a7e5446091', '24', 'Tavanic 500mg', 'Levofloxacin', 'BAT-177', '2027-02-20', 37, 115.83, 1, '2026-06-08 19:30:00'),
('2038970b-f42e-5905-a2b4-a2c160dd6ff4', '24', 'Cravit 500mg', 'Levofloxacin', 'BAT-177', '2027-02-20', 37, 28.71, 0, '2026-06-08 19:30:00'),
('d3035e25-acf2-5c25-86f6-4d050e8f9bc2', '24', 'Glucophage 500mg', 'Metformin', 'BAT-177', '2027-02-20', 37, 135.63, 1, '2026-06-08 19:30:00'),
('7eba5210-bede-515e-a2dc-04f54e252b88', '24', 'Glucophage XR 750mg', 'Metformin Extended Release', 'BAT-177', '2027-02-20', 37, 138.60, 0, '2026-06-08 19:30:00'),
('2624224e-996d-5830-a3a2-c7225fff35d4', '24', 'Diamicron 60mg', 'Gliclazide', 'BAT-177', '2027-02-20', 37, 18.81, 1, '2026-06-08 19:30:00'),
('55aae2c9-303b-576c-ac99-5ff26539e6db', '24', 'Januvia 100mg', 'Sitagliptin', 'BAT-177', '2027-02-20', 37, 138.60, 1, '2026-06-08 19:30:00'),
('8527fe57-a51c-54c7-af2a-25b29bac2dbd', '24', 'Antinal 400mg', 'Nifuroxazide', 'BAT-177', '2027-02-20', 37, 57.42, 1, '2026-06-08 19:30:00'),
('d270575b-34ee-50cd-840d-0769fd1c0431', '24', 'Entocid', 'Bismuth Subsalicylate', 'BAT-177', '2027-02-20', 37, 31.68, 0, '2026-06-08 19:30:00'),
('a07a6ff8-1bfe-50f5-b5b2-aafe0d0917a1', '24', 'Spasmex 20mg', 'Mebeverine', 'BAT-177', '2027-02-20', 37, 16.83, 1, '2026-06-08 19:30:00'),
('8207cafa-6c52-5690-a8f0-b0bb446c03e9', '24', 'Buscopan 10mg', 'Hyoscine Butylbromide', 'BAT-177', '2027-02-20', 37, 24.75, 1, '2026-06-08 19:30:00'),
('f9e467f9-4552-558f-a319-30da044860fc', '24', 'Miconazole Cream', 'Miconazole', 'BAT-177', '2027-02-20', 37, 132.66, 1, '2026-06-08 19:30:00'),
('fcc3ddb5-16ff-5444-a9c9-d6e9d521de62', '24', 'Canesten Cream', 'Clotrimazole', 'BAT-177', '2027-02-20', 37, 130.68, 0, '2026-06-08 19:30:00'),
('8b926614-5f24-59d1-a09d-173af231e842', '24', 'Fucicort Cream', 'Fusidic Acid + Betamethasone', 'BAT-177', '2027-02-20', 37, 137.61, 0, '2026-06-08 19:30:00'),
('49c74ea5-df37-5b34-ba33-e3025686a446', '24', 'Kenacort Injection', 'Triamcinolone', 'BAT-177', '2027-02-20', 37, 124.74, 1, '2026-06-08 19:30:00'),
('c3225936-c613-58e6-b1ca-c63e1f844471', '24', 'Depo-Medrol Injection', 'Methylprednisolone', 'BAT-177', '2027-02-20', 37, 67.32, 0, '2026-06-08 19:30:00'),
('1d1e1f1f-b199-570d-9e93-fbccc98e7f1d', '24', 'Hydrocortisone Cream 1%', 'Hydrocortisone', 'BAT-177', '2027-02-20', 37, 40.59, 1, '2026-06-08 19:30:00'),
('361c3311-9433-50c6-8f73-2e0dc18467a8', '24', 'Ebastel 10mg', 'Ebastine', 'BAT-177', '2027-02-20', 37, 35.64, 1, '2026-06-08 19:30:00'),
('d5496faa-370f-5d08-ab8b-078e07facfc1', '24', 'Telfast 180mg', 'Fexofenadine', 'BAT-177', '2027-02-20', 37, 64.35, 0, '2026-06-08 19:30:00'),
('1448724d-9415-5c64-85a5-db46194f6366', '24', 'Zyrtec 10mg', 'Cetirizine Hydrochloride', 'BAT-177', '2027-02-20', 37, 34.65, 0, '2026-06-08 19:30:00'),
('4e4e3480-5ac1-5a42-a109-fa91cab3e49b', '24', 'Claritin 10mg', 'Loratadine', 'BAT-177', '2027-02-20', 37, 44.55, 0, '2026-06-08 19:30:00'),
('d119b085-06bb-5546-b1e8-7ad6c13beec0', '24', 'Rhinathiol 200mg', 'Carbocisteine', 'BAT-177', '2027-02-20', 37, 80.19, 0, '2026-06-08 19:30:00'),
('d8ee3fed-9d79-5957-80a7-8c0fab6b978a', '24', 'Solmucol 600mg', 'Acetylcysteine', 'BAT-177', '2027-02-20', 37, 104.94, 0, '2026-06-08 19:30:00'),
('9cdd8bdd-76b8-5139-b14d-24f749b29870', '24', 'Bisolvon 8mg', 'Bromhexine', 'BAT-177', '2027-02-20', 37, 122.76, 1, '2026-06-08 19:30:00'),
('3231f20b-9fbd-5f0e-9ffa-55fc2987ef41', '24', 'Ventolin Inhaler', 'Salbutamol', 'BAT-177', '2027-02-20', 37, 44.55, 0, '2026-06-08 19:30:00'),
('3f4d24ab-03b4-518a-a71f-2eb2bf1872a3', '24', 'Seretide Inhaler', 'Fluticasone + Salmeterol', 'BAT-177', '2027-02-20', 37, 97.02, 1, '2026-06-08 19:30:00'),
('c7da9342-460e-58aa-9796-0a958a1a371a', '24', 'Singulair 10mg', 'Montelukast', 'BAT-177', '2027-02-20', 37, 42.57, 0, '2026-06-08 19:30:00'),
('19b329c8-3569-5be6-b708-34afdcb04c70', '24', 'Avamys Nasal Spray', 'Fluticasone Furoate', 'BAT-177', '2027-02-20', 37, 34.65, 0, '2026-06-08 19:30:00'),
('0ba716d1-726b-5e5d-b1af-b8754f6efabd', '24', 'Otrivin Nasal Spray', 'Xylometazoline', 'BAT-177', '2027-02-20', 37, 21.78, 0, '2026-06-08 19:30:00'),
('8c7dc1b0-f093-580f-98bb-9fd614050901', '24', 'Conventu', 'Conventu', 'BAT-177', '2027-02-20', 37, 17.82, 1, '2026-06-08 19:30:00'),
('6f83da1a-ab80-56db-a1a6-f23419daccb7', '24', 'Recoxibright', 'Etoricoxib', 'BAT-177', '2027-02-20', 37, 84.15, 0, '2026-06-08 19:30:00'),
('c0cc51c6-5788-5680-ba43-1415f9a066f6', '24', 'Sulfox', 'Cetyl Myristoleate + Glucosamine + MSM', 'BAT-177', '2027-02-20', 37, 49.50, 1, '2026-06-08 19:30:00'),
('7999121a-e0af-5e6c-8741-d05fcbe343de', '24', 'Sulfora gel', 'Cetyl Myristoleate + Glucosamine + MSM', 'BAT-177', '2027-02-20', 37, 137.61, 1, '2026-06-08 19:30:00'),
('0b3ccdd5-8881-5104-96ea-8adc136fab40', '24', 'Random Drug 50mg', 'Random Drug 50mg', 'BAT-177', '2027-02-20', 37, 115.83, 0, '2026-06-08 19:30:00'),
('5535198a-c987-5292-b669-15daf2c107e2', '24', 'Convenntu 100mg', 'Convenntu 100mg', 'BAT-177', '2027-02-20', 37, 118.80, 0, '2026-06-08 19:30:00'),
('472693e8-6a35-58ac-9ac5-d1cf85272d11', '24', 'Recoribright 90mg', 'Recoribright 90mg', 'BAT-177', '2027-02-20', 37, 51.48, 0, '2026-06-08 19:30:00'),
('5237bfb7-37f3-5746-9719-958990f5da44', '24', 'Sulfoa gel', 'Cetyl Myristoleate + Glucosamine + MSM', 'BAT-177', '2027-02-20', 37, 103.95, 1, '2026-06-08 19:30:00'),
('0a6012a4-373f-5805-8748-fde0de9eb161', '24', 'Sulfiox gel', 'Sulfiox gel', 'BAT-177', '2027-02-20', 37, 47.52, 1, '2026-06-08 19:30:00'),
('12b29eef-b315-50fc-80a3-d6527add2909', '24', 'Conventus', 'Conventus', 'BAT-177', '2027-02-20', 37, 141.57, 1, '2026-06-08 19:30:00'),
('b5e92dc7-ef35-58e4-adb6-c254330505c5', '24', 'Convenia 100mg', 'Convenia 100mg', 'BAT-177', '2027-02-20', 37, 115.83, 0, '2026-06-08 19:30:00'),
('33bafe1f-b559-577d-b36f-79a78033a27c', '24', 'TestMed3', 'TestMed3', 'BAT-177', '2027-02-20', 37, 52.47, 1, '2026-06-08 19:30:00'),
('41bf9b12-6ca5-5982-9c18-4b36e0b85862', '24', 'Conventin 100mg', 'Gabapentin', 'BAT-177', '2027-02-20', 37, 69.30, 1, '2026-06-08 19:30:00'),
('f2f8a49a-2e5a-518e-9baf-99250266e96a', '24', 'Recoxibright 90mg', 'Etoricoxib', 'BAT-177', '2027-02-20', 37, 94.05, 0, '2026-06-08 19:30:00'),
('3882d83e-12a3-5107-9ae6-056d1129a560', '24', 'Sulfax Gel', 'Cetyl Myristoleate + Glucosamine + MSM', 'BAT-177', '2027-02-20', 37, 54.45, 1, '2026-06-08 19:30:00'),
('0f1d7ca1-d268-58ff-9f4d-cf174c037cfe', '24', 'Venusen Compression Stocking (Class II, XL, Under-knee)', 'OCR Extracted', 'BAT-177', '2027-02-20', 37, 178.20, 1, '2026-06-08 19:30:00'),
('6dbb29bc-f82e-56c9-a404-a9babc53ec52', '24', 'Venusen Medical Compression Stockings (Below Knee)', 'OCR Extracted', 'BAT-177', '2027-02-20', 37, 178.20, 1, '2026-06-08 19:30:00'),
('3d5f71da-881d-5f4e-9380-05cd485d609f', '24', 'Venusen Compression Stocking (Below Knee, Class II, XL)', 'OCR Extracted', 'BAT-177', '2027-02-20', 37, 178.20, 1, '2026-06-08 19:30:00'),
('0f4a6947-356b-52b7-b2cb-a08f353134c1', '24', 'NonExistent Medicine', 'OCR Extracted', 'BAT-177', '2027-02-20', 37, 134.64, 1, '2026-06-08 19:30:00'),
('dff85232-12d1-5ed9-ae2e-203413f3b7ef', '24', 'Venosen Compression Stockings (Below Knee, Class II, XL)', 'OCR Extracted', 'BAT-177', '2027-02-20', 37, 178.20, 0, '2026-06-08 19:30:00'),
('f308eaad-4c6c-5fe2-9ec0-7f9fb52d2c2b', '24', 'Prescribed Items', 'OCR Extracted', 'BAT-177', '2027-02-20', 37, 67.32, 0, '2026-06-08 19:30:00'),
('9938e3a6-26c1-5b1a-885b-75d47a7fe227', '24', 'Panadol Extra', 'Paracetamol + Caffeine', 'BAT-177', '2027-02-20', 37, 23.76, 0, '2026-06-08 19:30:00'),
('51cef2e7-6764-5afd-855c-85fee9e7f4c1', '24', 'Solpadeine Active', 'Paracetamol + Caffeine + Codeine', 'BAT-177', '2027-02-20', 37, 19.80, 0, '2026-06-08 19:30:00'),
('3475de93-627c-5f06-9689-2c6fb22a4901', '24', 'Lipitor 20mg', 'Atorvastatin Calcium', 'BAT-177', '2027-02-20', 37, 129.69, 0, '2026-06-08 19:30:00'),
('fc4101ff-b112-572f-8fd6-da3b0bef4f9f', '24', 'Nexium 40mg', 'Esomeprazole', 'BAT-177', '2027-02-20', 37, 84.15, 0, '2026-06-08 19:30:00'),
('82623c8e-d552-5c03-8c40-88b0115d9325', '24', 'Augmentin 1gm', 'Amoxicillin + Clavulanate Potassium', 'BAT-177', '2027-02-20', 37, 84.15, 1, '2026-06-08 19:30:00'),
('073ca15b-676e-551c-8130-2648026a1868', '24', 'Cataflam 50mg', 'Diclofenac Potassium', 'BAT-177', '2027-02-20', 37, 35.64, 1, '2026-06-08 19:30:00'),
('e52d86b5-d47c-5aa4-90f3-2ea5b977169a', '24', 'Flotac', 'OCR Extracted', 'BAT-177', '2027-02-20', 37, 63.36, 0, '2026-06-08 19:30:00'),
('7b1af9f7-9623-593d-8a3a-a974e4978809', '24', 'Duphaston', 'OCR Extracted', 'BAT-177', '2027-02-20', 37, 118.80, 0, '2026-06-08 19:30:00'),
('aa831376-fbcc-5f1a-88ac-2c1312b002c5', '24', 'H Daben Capsule', 'OCR Extracted', 'BAT-177', '2027-02-20', 37, 50.49, 0, '2026-06-08 19:30:00'),
('19f93ef1-2695-5e74-9f6f-bcc0383f2d67', '24', 'MegaVera 120mg Test', 'OCR Extracted', 'BAT-177', '2027-02-20', 37, 25.74, 1, '2026-06-08 19:30:00'),
('5f0b98bc-7df3-54f7-9266-4dd079ffde68', '24', 'Venesen Compression Stockings, Knee-high, Size XL, Class II', 'OCR Extracted', 'BAT-177', '2027-02-20', 37, 121.77, 0, '2026-06-08 19:30:00'),
('8018bb54-d61b-5fe3-9f54-ae52fad7b5f8', '24', 'E2ETestMedicine', 'E2ETestGeneric', 'BAT-177', '2027-02-20', 37, 105.93, 0, '2026-06-08 19:30:00'),
('c432381f-78cf-593c-aad7-cbf4bdac5509', '24', 'Cozaar 50mg', 'Losartan Potassium (Cozaar)', 'BAT-177', '2027-02-20', 37, 86.13, 1, '2026-06-08 19:30:00'),
('9ecae864-8051-5f46-8a30-4d6b3ac4a8b6', '24', 'Pecoribright', 'OCR Extracted', 'BAT-177', '2027-02-20', 37, 41.58, 0, '2026-06-08 19:30:00'),
('d58bb0ad-8f44-518c-b9a7-743074c4c365', '24', 'Venuson Compression Stocking', 'OCR Extracted', 'BAT-177', '2027-02-20', 37, 178.20, 1, '2026-06-08 19:30:00'),
('3a518cd9-412c-54b7-90c7-a3276981836e', '24', 'Venusen Compression Stocking Class II, XL (Below Knee, Open Toe)', 'OCR Extracted', 'BAT-177', '2027-02-20', 37, 178.20, 1, '2026-06-08 19:30:00'),
('e2099b64-e45b-5fc8-963f-066349b360a9', '24', 'Venusen Compression Stocking (Below Knee, Open Toe)', 'OCR Extracted', 'BAT-177', '2027-02-20', 37, 178.20, 1, '2026-06-08 19:30:00'),
('b3e08b3d-c233-54b7-aa70-00cf91d193ae', '24', 'Gluonorm', 'OCR Extracted', 'BAT-177', '2027-02-20', 37, 111.87, 0, '2026-06-08 19:30:00'),
('57c3a4ca-85ed-5a14-ba8a-d612ae7b3894', '24', 'Furamil', 'OCR Extracted', 'BAT-177', '2027-02-20', 37, 28.71, 1, '2026-06-08 19:30:00'),
('9d02bc8a-cdae-5e24-87b1-46a108087f45', '24', 'Jivomed', 'OCR Extracted', 'BAT-177', '2027-02-20', 37, 73.26, 0, '2026-06-08 19:30:00'),
('94b8de6b-eb19-5819-b823-e553840ad138', '24', 'Thiopro', 'OCR Extracted', 'BAT-177', '2027-02-20', 37, 108.90, 0, '2026-06-08 19:30:00'),
('670c1aa9-53f0-5659-8826-9ab10af386cc', '24', 'Unresolved Medicine', 'OCR Extracted', 'BAT-177', '2027-02-20', 37, 33.66, 1, '2026-06-08 19:30:00'),
('539b5673-76b2-57b4-9739-de6b5ccd5b90', '24', 'Conveniui', 'OCR Extracted', 'BAT-177', '2027-02-20', 37, 74.25, 1, '2026-06-08 19:30:00'),
('147b1462-adc9-55d7-8d7c-b105cb080b2c', '24', 'Puravil', 'OCR Extracted', 'BAT-177', '2027-02-20', 37, 89.10, 1, '2026-06-08 19:30:00'),
('a3b9a633-e688-5e38-89ac-6052e3972447', '24', 'Convenlur', 'OCR Extracted', 'BAT-177', '2027-02-20', 37, 116.82, 1, '2026-06-08 19:30:00'),
('885527e2-c1fe-5700-b40e-43aca920101e', '25', 'Paracetamol', 'Acetaminophen', 'BAT-493', '2027-07-06', 23, 15.00, 0, '2026-06-08 19:30:00'),
('7585b2d3-f1e9-591d-95fd-3da3405113ee', '25', 'Ibuprofen', 'Ibuprofen', 'BAT-493', '2027-07-06', 23, 22.00, 1, '2026-06-08 19:30:00'),
('764eb119-b4d9-5219-b907-f2c0eb91ba20', '25', 'Amoxicillin', 'Amoxicillin', 'BAT-493', '2027-07-06', 23, 35.00, 0, '2026-06-08 19:30:00'),
('d2d8bf94-44e3-5a65-a74e-b3f06de6e029', '25', 'Ventolin', 'Salbutamol', 'BAT-493', '2027-07-06', 23, 33.00, 1, '2026-06-08 19:30:00'),
('514a842c-effd-5edf-bfc8-db53f3d7e943', '25', 'Paracetamol 500mg', 'Acetaminophen', 'BAT-493', '2027-07-06', 23, 18.00, 1, '2026-06-08 19:30:00'),
('ec104739-868f-5259-8b6c-c4fd56b2f83f', '25', 'Ibuprofen 400mg', 'Ibuprofen', 'BAT-493', '2027-07-06', 23, 26.00, 0, '2026-06-08 19:30:00'),
('4983da27-e71d-50ad-8659-972742703d43', '25', 'Amoxicillin 500mg', 'Amoxicillin (Penicillin Antibiotic)', 'BAT-493', '2027-07-06', 23, 42.00, 0, '2026-06-08 19:30:00'),
('5a04570b-99f3-5607-b074-3c2f53831407', '25', 'Azithromycin 500mg', 'Azithromycin', 'BAT-493', '2027-07-06', 23, 94.00, 0, '2026-06-08 19:30:00'),
('6d089a25-7905-51a4-a7ee-72c4678cb5a0', '25', 'Ciprofloxacin 500mg', 'Ciprofloxacin', 'BAT-493', '2027-07-06', 23, 50.00, 1, '2026-06-08 19:30:00'),
('9229c2ab-c46a-5b88-a11a-5093c8621b5e', '25', 'Doxycycline 100mg', 'Doxycycline', 'BAT-493', '2027-07-06', 23, 66.00, 1, '2026-06-08 19:30:00'),
('c6596fc1-cd1e-5c8c-b27b-676be7fead7e', '25', 'Metformin 500mg', 'Metformin', 'BAT-493', '2027-07-06', 23, 25.00, 0, '2026-06-08 19:30:00'),
('045f4fa5-469d-55c3-b915-4b31bae37383', '25', 'Omeprazole 20mg', 'Omeprazole', 'BAT-493', '2027-07-06', 23, 101.00, 1, '2026-06-08 19:30:00'),
('1426a09d-6397-5ebe-965e-8a706aaeed95', '25', 'Lisinopril 10mg', 'Lisinopril', 'BAT-493', '2027-07-06', 23, 74.00, 0, '2026-06-08 19:30:00'),
('97a65dcb-5fb7-5337-8c82-3fe692893e0d', '25', 'Amlodipine 5mg', 'Amlodipine', 'BAT-493', '2027-07-06', 23, 111.00, 0, '2026-06-08 19:30:00'),
('8dd25814-4cb2-5b49-b959-2c0495408547', '25', 'Atorvastatin 20mg', 'Atorvastatin', 'BAT-493', '2027-07-06', 23, 42.00, 1, '2026-06-08 19:30:00'),
('e6a5c259-d647-598d-81ce-0da4aa951939', '25', 'Losartan 50mg', 'Losartan', 'BAT-493', '2027-07-06', 23, 133.00, 0, '2026-06-08 19:30:00'),
('755f6261-7fe0-55d8-8141-f1040d1eb29e', '25', 'Gabapentin 300mg', 'Gabapentin', 'BAT-493', '2027-07-06', 23, 39.00, 0, '2026-06-08 19:30:00'),
('0608df75-528f-5567-98ef-dad5ab304398', '25', 'Tramadol 50mg', 'Tramadol', 'BAT-493', '2027-07-06', 23, 111.00, 1, '2026-06-08 19:30:00'),
('30971df0-11e5-52e9-bf3d-65234144372f', '25', 'Cetirizine 10mg', 'Cetirizine', 'BAT-493', '2027-07-06', 23, 28.00, 1, '2026-06-08 19:30:00'),
('4ba327d2-692c-5dac-a8c8-2e4b3571bb5d', '25', 'Loratadine 10mg', 'Loratadine', 'BAT-493', '2027-07-06', 23, 38.00, 0, '2026-06-08 19:30:00'),
('b8ad8309-30f5-571c-a003-287fb9ca54ae', '25', 'Fexofenadine 180mg', 'Fexofenadine', 'BAT-493', '2027-07-06', 23, 58.00, 1, '2026-06-08 19:30:00'),
('7dee0107-fb31-50cd-a6f3-62fa0b0c7aa5', '25', 'Prednisolone 5mg', 'Prednisolone', 'BAT-493', '2027-07-06', 23, 71.00, 1, '2026-06-08 19:30:00'),
('5193546c-45f3-56ff-ab9e-4c51f1b8b285', '25', 'Dexamethasone 4mg', 'Dexamethasone', 'BAT-493', '2027-07-06', 23, 92.00, 0, '2026-06-08 19:30:00'),
('57348791-08fd-5ea8-84d9-99c6e43ea905', '25', 'Hydrochlorothiazide 25mg', 'HCTZ', 'BAT-493', '2027-07-06', 23, 60.00, 1, '2026-06-08 19:30:00'),
('2a5bd3d9-39c1-5d54-81dd-1ae7cb0f6558', '25', 'Furosemide 40mg', 'Furosemide', 'BAT-493', '2027-07-06', 23, 98.00, 1, '2026-06-08 19:30:00'),
('e4f978b5-146b-5246-8d86-49d5505cd30e', '25', 'Spironolactone 25mg', 'Spironolactone', 'BAT-493', '2027-07-06', 23, 61.00, 1, '2026-06-08 19:30:00'),
('22e734fc-5437-5461-bbe4-2f8dffee46bb', '25', 'Warfarin 5mg', 'Warfarin', 'BAT-493', '2027-07-06', 23, 25.00, 1, '2026-06-08 19:30:00'),
('ec9d3dba-2665-5970-9401-3e4107d5e124', '25', 'Aspirin 81mg', 'Aspirin', 'BAT-493', '2027-07-06', 23, 12.00, 1, '2026-06-08 19:30:00'),
('5a8f1a08-5026-5519-ba00-41505af540a5', '25', 'Clopidogrel 75mg', 'Clopidogrel', 'BAT-493', '2027-07-06', 23, 25.00, 1, '2026-06-08 19:30:00'),
('7b492f78-ca5c-5878-86a5-db2dd6654c67', '25', 'Digoxin 0.25mg', 'Digoxin', 'BAT-493', '2027-07-06', 23, 25.00, 0, '2026-06-08 19:30:00'),
('727f5539-9811-58bc-9be5-e995f6e71714', '25', 'Levothyroxine 100mcg', 'Levothyroxine', 'BAT-493', '2027-07-06', 23, 133.00, 1, '2026-06-08 19:30:00'),
('a7cc6b36-24a6-58f7-9b44-dca7e4eb7682', '25', 'Insulin Aspart', 'Insulin Aspart', 'BAT-493', '2027-07-06', 23, 37.00, 0, '2026-06-08 19:30:00'),
('e77db21b-576c-582c-b8a5-01822a385c49', '25', 'Metronidazole 500mg', 'Metronidazole', 'BAT-493', '2027-07-06', 23, 22.00, 1, '2026-06-08 19:30:00'),
('d397d3f5-3e79-5ed6-81cb-2ca2ab6668eb', '25', 'Fluconazole 150mg', 'Fluconazole', 'BAT-493', '2027-07-06', 23, 146.00, 0, '2026-06-08 19:30:00'),
('e0bc276b-3c71-5a9d-ba82-9b74bca32d7a', '25', 'Acyclovir 400mg', 'Acyclovir', 'BAT-493', '2027-07-06', 23, 19.00, 1, '2026-06-08 19:30:00'),
('337894a1-e3f2-592e-a28f-9e21e6b2b8a1', '25', 'Clindamycin 300mg', 'Clindamycin', 'BAT-493', '2027-07-06', 23, 26.00, 0, '2026-06-08 19:30:00'),
('c302a300-1e05-5dc1-9f57-81ce7bf0b347', '25', 'Cephalexin 500mg', 'Cephalexin', 'BAT-493', '2027-07-06', 23, 15.00, 0, '2026-06-08 19:30:00'),
('abaa3958-c626-57e9-8848-3302ece44ebe', '25', 'Nitrofurantoin 100mg', 'Nitrofurantoin', 'BAT-493', '2027-07-06', 23, 36.00, 0, '2026-06-08 19:30:00'),
('84d838ae-45f7-5f75-88f5-0c4866257466', '25', 'Albuterol Inhaler', 'Salbutamol', 'BAT-493', '2027-07-06', 23, 127.00, 0, '2026-06-08 19:30:00'),
('a672369c-3881-5817-8583-641170cb265a', '25', 'Fluticasone Inhaler', 'Fluticasone', 'BAT-493', '2027-07-06', 23, 148.00, 0, '2026-06-08 19:30:00'),
('316871c8-1248-54ef-bbde-79a1275ac0bb', '25', 'Montelukast 10mg', 'Montelukast', 'BAT-493', '2027-07-06', 23, 44.00, 0, '2026-06-08 19:30:00'),
('7b281d1f-460d-5a39-8c86-25c6dc6c1e16', '25', 'Esomeprazole 40mg', 'Esomeprazole', 'BAT-493', '2027-07-06', 23, 120.00, 0, '2026-06-08 19:30:00'),
('f83a8ab1-c1fb-5bb0-b378-ec05b9130c56', '25', 'Pantoprazole 40mg', 'Pantoprazole', 'BAT-493', '2027-07-06', 23, 24.00, 1, '2026-06-08 19:30:00'),
('31020dfe-a506-5a66-a532-ebabdb369537', '25', 'Ranitidine 150mg', 'Ranitidine', 'BAT-493', '2027-07-06', 23, 28.00, 0, '2026-06-08 19:30:00'),
('7b4f45f6-b389-5d52-ac08-f1efd9f12150', '25', 'Panadol Extra 500mg', 'Paracetamol + Caffeine', 'BAT-493', '2027-07-06', 23, 25.00, 0, '2026-06-08 19:30:00'),
('42b06f07-e4e1-5578-a9fd-2afa727c1f73', '25', 'Panadol Cold & Flu', 'Paracetamol + Pseudoephedrine', 'BAT-493', '2027-07-06', 23, 28.00, 0, '2026-06-08 19:30:00'),
('e390b6fe-247b-54e5-aaae-97486bce3f0c', '25', 'Catafast 50mg', 'Diclofenac Potassium', 'BAT-493', '2027-07-06', 23, 38.00, 1, '2026-06-08 19:30:00'),
('ce0417c6-173e-5b7c-b4ae-9265b6a0d30b', '25', 'Voltaren 75mg', 'Diclofenac Sodium', 'BAT-493', '2027-07-06', 23, 48.00, 1, '2026-06-08 19:30:00'),
('00d09881-43a7-5591-9e4b-d6ff86792c36', '25', 'Mortal 400mg', 'Ibuprofen', 'BAT-493', '2027-07-06', 23, 58.00, 0, '2026-06-08 19:30:00'),
('2daddac8-eabd-5fb4-ab66-0452edf0e224', '25', 'Brufen 600mg', 'Ibuprofen', 'BAT-493', '2027-07-06', 23, 32.00, 0, '2026-06-08 19:30:00'),
('bd7a4e64-fae9-5873-98a9-a5b65ecbdb79', '25', 'Amoxil 500mg', 'Amoxicillin', 'BAT-493', '2027-07-06', 23, 45.00, 0, '2026-06-08 19:30:00'),
('35100cf0-553d-5154-b0ab-f6dcde67b4af', '25', 'Augmentin 1g', 'Amoxicillin + Clavulanic acid', 'BAT-493', '2027-07-06', 23, 95.00, 0, '2026-06-08 19:30:00'),
('9ff761af-0928-5e0e-8f34-b5eea2df7619', '25', 'Ciprinol 500mg', 'Ciprofloxacin', 'BAT-493', '2027-07-06', 23, 128.00, 0, '2026-06-08 19:30:00'),
('a3de444a-5d52-5803-8f3d-4c8b053756f8', '25', 'Zithromax 500mg', 'Azithromycin', 'BAT-493', '2027-07-06', 23, 116.00, 0, '2026-06-08 19:30:00'),
('118d48df-27a7-5c31-a519-75444d8ccbae', '25', 'Flagyl 500mg', 'Metronidazole', 'BAT-493', '2027-07-06', 23, 24.00, 1, '2026-06-08 19:30:00'),
('94bb5099-57d1-587f-a546-158ee8191200', '25', 'Rocephin 1g', 'Ceftriaxone', 'BAT-493', '2027-07-06', 23, 119.00, 1, '2026-06-08 19:30:00'),
('b1b82efe-8ca9-54b5-b3e5-8bd20c9a8bf5', '25', 'Tavanic 500mg', 'Levofloxacin', 'BAT-493', '2027-07-06', 23, 117.00, 1, '2026-06-08 19:30:00'),
('7781d168-5f6b-5cda-af1d-00c636e9f5ce', '25', 'Cravit 500mg', 'Levofloxacin', 'BAT-493', '2027-07-06', 23, 29.00, 0, '2026-06-08 19:30:00'),
('1f608597-ac6a-5378-8417-965f812cf960', '25', 'Glucophage 500mg', 'Metformin', 'BAT-493', '2027-07-06', 23, 137.00, 1, '2026-06-08 19:30:00'),
('66016062-168a-57bf-a99b-ce5014f70e18', '25', 'Glucophage XR 750mg', 'Metformin Extended Release', 'BAT-493', '2027-07-06', 23, 140.00, 1, '2026-06-08 19:30:00'),
('3cf1c763-a4aa-5ae7-bafe-b89a92ff8ec8', '25', 'Diamicron 60mg', 'Gliclazide', 'BAT-493', '2027-07-06', 23, 19.00, 1, '2026-06-08 19:30:00'),
('bb283898-3fa3-5403-9b7a-fe9cd7487078', '25', 'Januvia 100mg', 'Sitagliptin', 'BAT-493', '2027-07-06', 23, 140.00, 1, '2026-06-08 19:30:00'),
('db3e67c2-d176-54d3-b0f5-4c641db4b020', '25', 'Antinal 400mg', 'Nifuroxazide', 'BAT-493', '2027-07-06', 23, 58.00, 1, '2026-06-08 19:30:00'),
('d3c7e8e4-5b89-54a6-99e0-b729d522b2d8', '25', 'Entocid', 'Bismuth Subsalicylate', 'BAT-493', '2027-07-06', 23, 32.00, 1, '2026-06-08 19:30:00'),
('4e0e2712-05a1-5be2-9e8f-9ca9a97060a0', '25', 'Spasmex 20mg', 'Mebeverine', 'BAT-493', '2027-07-06', 23, 17.00, 0, '2026-06-08 19:30:00'),
('4ea35274-6501-56cd-8636-2d72bd159685', '25', 'Buscopan 10mg', 'Hyoscine Butylbromide', 'BAT-493', '2027-07-06', 23, 25.00, 1, '2026-06-08 19:30:00'),
('cc269860-1e18-5d11-8650-4504ef4c18bb', '25', 'Miconazole Cream', 'Miconazole', 'BAT-493', '2027-07-06', 23, 134.00, 1, '2026-06-08 19:30:00'),
('4c252211-186b-50b3-9800-ec9301ebcc85', '25', 'Canesten Cream', 'Clotrimazole', 'BAT-493', '2027-07-06', 23, 132.00, 1, '2026-06-08 19:30:00'),
('34fd6077-1ea9-542b-9b61-257bfa9582cf', '25', 'Fucicort Cream', 'Fusidic Acid + Betamethasone', 'BAT-493', '2027-07-06', 23, 139.00, 1, '2026-06-08 19:30:00'),
('d7407e8c-110b-50ac-95ad-7e34cfe53884', '25', 'Kenacort Injection', 'Triamcinolone', 'BAT-493', '2027-07-06', 23, 126.00, 0, '2026-06-08 19:30:00'),
('315e812b-47e8-58d4-9eba-9d2c775c213e', '25', 'Depo-Medrol Injection', 'Methylprednisolone', 'BAT-493', '2027-07-06', 23, 68.00, 0, '2026-06-08 19:30:00'),
('3b4cf971-067c-5def-97ce-ce900b8b829a', '25', 'Hydrocortisone Cream 1%', 'Hydrocortisone', 'BAT-493', '2027-07-06', 23, 41.00, 0, '2026-06-08 19:30:00'),
('c48a0913-3d69-5cce-b848-f22753add20c', '25', 'Ebastel 10mg', 'Ebastine', 'BAT-493', '2027-07-06', 23, 36.00, 1, '2026-06-08 19:30:00'),
('e712df74-7b68-505e-8bed-3f00d6f1144e', '25', 'Telfast 180mg', 'Fexofenadine', 'BAT-493', '2027-07-06', 23, 65.00, 1, '2026-06-08 19:30:00'),
('7cbdb530-6224-5639-87c6-80f0457cf5cf', '25', 'Zyrtec 10mg', 'Cetirizine Hydrochloride', 'BAT-493', '2027-07-06', 23, 35.00, 0, '2026-06-08 19:30:00'),
('d67e0e77-f304-5634-a839-54e40de37a9a', '25', 'Claritin 10mg', 'Loratadine', 'BAT-493', '2027-07-06', 23, 45.00, 0, '2026-06-08 19:30:00'),
('a8c10918-583b-507e-823e-7a486fe542f2', '25', 'Rhinathiol 200mg', 'Carbocisteine', 'BAT-493', '2027-07-06', 23, 81.00, 1, '2026-06-08 19:30:00'),
('510491f8-07e4-551a-b7ce-a76e2cf2dd21', '25', 'Solmucol 600mg', 'Acetylcysteine', 'BAT-493', '2027-07-06', 23, 106.00, 1, '2026-06-08 19:30:00'),
('d41bb05d-5508-5612-bd1e-343722cde26f', '25', 'Bisolvon 8mg', 'Bromhexine', 'BAT-493', '2027-07-06', 23, 124.00, 1, '2026-06-08 19:30:00'),
('1130bb6d-2fe7-5ebe-9615-6cecaa6e57c9', '25', 'Ventolin Inhaler', 'Salbutamol', 'BAT-493', '2027-07-06', 23, 45.00, 0, '2026-06-08 19:30:00'),
('c099174c-c122-53df-ab15-8a101c0f47f4', '25', 'Seretide Inhaler', 'Fluticasone + Salmeterol', 'BAT-493', '2027-07-06', 23, 98.00, 0, '2026-06-08 19:30:00'),
('224fabe5-0c21-56ec-9423-d58ecf7143fd', '25', 'Singulair 10mg', 'Montelukast', 'BAT-493', '2027-07-06', 23, 43.00, 1, '2026-06-08 19:30:00'),
('2ba35fc6-43fb-52fb-990e-78b317b72c75', '25', 'Avamys Nasal Spray', 'Fluticasone Furoate', 'BAT-493', '2027-07-06', 23, 35.00, 0, '2026-06-08 19:30:00'),
('7620d37a-ab6a-573d-ab09-7825edf656d5', '25', 'Otrivin Nasal Spray', 'Xylometazoline', 'BAT-493', '2027-07-06', 23, 22.00, 0, '2026-06-08 19:30:00'),
('c45ebcfc-77dd-5cdb-88d6-20a5da2ca624', '25', 'Conventu', 'Conventu', 'BAT-493', '2027-07-06', 23, 18.00, 1, '2026-06-08 19:30:00'),
('387fdd59-be04-5b1c-90f6-58c7184ab34d', '25', 'Recoxibright', 'Etoricoxib', 'BAT-493', '2027-07-06', 23, 85.00, 1, '2026-06-08 19:30:00'),
('861fe4da-a41e-53d0-acf8-ce72930aaab8', '25', 'Sulfox', 'Cetyl Myristoleate + Glucosamine + MSM', 'BAT-493', '2027-07-06', 23, 50.00, 0, '2026-06-08 19:30:00'),
('38e14e97-b49e-5bbe-824c-d1b05b308829', '25', 'Sulfora gel', 'Cetyl Myristoleate + Glucosamine + MSM', 'BAT-493', '2027-07-06', 23, 139.00, 1, '2026-06-08 19:30:00'),
('dcb8d31c-0703-58ca-b213-35a602b3ed9f', '25', 'Random Drug 50mg', 'Random Drug 50mg', 'BAT-493', '2027-07-06', 23, 117.00, 0, '2026-06-08 19:30:00'),
('8811fc1c-9197-5b48-9fc2-430aca110ea8', '25', 'Convenntu 100mg', 'Convenntu 100mg', 'BAT-493', '2027-07-06', 23, 120.00, 0, '2026-06-08 19:30:00'),
('88ebd092-2d16-5568-b89b-59f251942ac9', '25', 'Recoribright 90mg', 'Recoribright 90mg', 'BAT-493', '2027-07-06', 23, 52.00, 1, '2026-06-08 19:30:00'),
('099c2399-aea0-5c9d-97d7-bda49755d464', '25', 'Sulfoa gel', 'Cetyl Myristoleate + Glucosamine + MSM', 'BAT-493', '2027-07-06', 23, 105.00, 1, '2026-06-08 19:30:00'),
('6107a8d6-1630-5563-b657-c1ab2bd472e0', '25', 'Sulfiox gel', 'Sulfiox gel', 'BAT-493', '2027-07-06', 23, 48.00, 1, '2026-06-08 19:30:00'),
('51fea33c-8fb7-5683-af10-544264cd9d6d', '25', 'Conventus', 'Conventus', 'BAT-493', '2027-07-06', 23, 143.00, 1, '2026-06-08 19:30:00'),
('02d1c246-ca62-56c2-b5b4-340d2390fb63', '25', 'Convenia 100mg', 'Convenia 100mg', 'BAT-493', '2027-07-06', 23, 117.00, 0, '2026-06-08 19:30:00'),
('61d15dcb-8499-52b3-9f41-1e3ba6378cb2', '25', 'TestMed3', 'TestMed3', 'BAT-493', '2027-07-06', 23, 53.00, 0, '2026-06-08 19:30:00'),
('570dd17f-4a5a-5cec-9137-c7c292322375', '25', 'Conventin 100mg', 'Gabapentin', 'BAT-493', '2027-07-06', 23, 70.00, 1, '2026-06-08 19:30:00'),
('911263a4-b521-570a-ac16-149928e3263c', '25', 'Recoxibright 90mg', 'Etoricoxib', 'BAT-493', '2027-07-06', 23, 95.00, 1, '2026-06-08 19:30:00'),
('de2f5004-340e-53b2-b1c1-ef1bbe9a7f05', '25', 'Sulfax Gel', 'Cetyl Myristoleate + Glucosamine + MSM', 'BAT-493', '2027-07-06', 23, 55.00, 1, '2026-06-08 19:30:00'),
('a601f22e-e59c-55d2-a250-0435c92de623', '25', 'Venusen Compression Stocking (Class II, XL, Under-knee)', 'OCR Extracted', 'BAT-493', '2027-07-06', 23, 180.00, 1, '2026-06-08 19:30:00'),
('51c6e3be-b7f0-5af6-a362-a0017b48da6a', '25', 'Venusen Medical Compression Stockings (Below Knee)', 'OCR Extracted', 'BAT-493', '2027-07-06', 23, 180.00, 0, '2026-06-08 19:30:00'),
('d6167559-cef8-54c6-bcdb-9948c6002014', '25', 'Venusen Compression Stocking (Below Knee, Class II, XL)', 'OCR Extracted', 'BAT-493', '2027-07-06', 23, 180.00, 0, '2026-06-08 19:30:00'),
('9ced4024-f52c-59b1-ab4d-b25d56a44203', '25', 'NonExistent Medicine', 'OCR Extracted', 'BAT-493', '2027-07-06', 23, 136.00, 1, '2026-06-08 19:30:00'),
('a9a32aa6-da6c-5e2f-8184-300e9f4dac00', '25', 'Venosen Compression Stockings (Below Knee, Class II, XL)', 'OCR Extracted', 'BAT-493', '2027-07-06', 23, 180.00, 0, '2026-06-08 19:30:00'),
('d3c4fca9-44bf-5e7c-a757-2d7ca52a8fab', '25', 'Prescribed Items', 'OCR Extracted', 'BAT-493', '2027-07-06', 23, 68.00, 0, '2026-06-08 19:30:00'),
('850aa329-ade7-5fd2-bff5-20e8f64fb6f6', '25', 'Panadol Extra', 'Paracetamol + Caffeine', 'BAT-493', '2027-07-06', 23, 24.00, 1, '2026-06-08 19:30:00'),
('fdafcdad-1e2c-556b-a95f-169b82037710', '25', 'Solpadeine Active', 'Paracetamol + Caffeine + Codeine', 'BAT-493', '2027-07-06', 23, 20.00, 1, '2026-06-08 19:30:00'),
('f16616da-a83c-53dd-ab52-854a96d7c077', '25', 'Lipitor 20mg', 'Atorvastatin Calcium', 'BAT-493', '2027-07-06', 23, 131.00, 0, '2026-06-08 19:30:00'),
('0b04d5d5-7b7e-5644-b22d-9dc8710a4814', '25', 'Nexium 40mg', 'Esomeprazole', 'BAT-493', '2027-07-06', 23, 85.00, 0, '2026-06-08 19:30:00'),
('f50a6dd0-5113-5264-8c36-6a9efa430674', '25', 'Augmentin 1gm', 'Amoxicillin + Clavulanate Potassium', 'BAT-493', '2027-07-06', 23, 85.00, 0, '2026-06-08 19:30:00'),
('d377b104-2681-58c4-8600-928c75c39b2d', '25', 'Cataflam 50mg', 'Diclofenac Potassium', 'BAT-493', '2027-07-06', 23, 36.00, 0, '2026-06-08 19:30:00'),
('bbe29435-141c-51b0-8e2e-83ca1c733e42', '25', 'Flotac', 'OCR Extracted', 'BAT-493', '2027-07-06', 23, 64.00, 1, '2026-06-08 19:30:00'),
('f9916c09-0e33-55d8-953a-1a7f8b2fd8d4', '25', 'Duphaston', 'OCR Extracted', 'BAT-493', '2027-07-06', 23, 120.00, 0, '2026-06-08 19:30:00'),
('4a98b05a-c60a-52fe-b592-322f53d0ec9b', '25', 'H Daben Capsule', 'OCR Extracted', 'BAT-493', '2027-07-06', 23, 51.00, 1, '2026-06-08 19:30:00'),
('8c81096f-061c-5b27-aca0-2aa0a17b939b', '25', 'MegaVera 120mg Test', 'OCR Extracted', 'BAT-493', '2027-07-06', 23, 26.00, 0, '2026-06-08 19:30:00'),
('6424785a-c563-5846-b6a5-f8926a010f0e', '25', 'Venesen Compression Stockings, Knee-high, Size XL, Class II', 'OCR Extracted', 'BAT-493', '2027-07-06', 23, 123.00, 1, '2026-06-08 19:30:00'),
('dd3d7b1d-b572-5735-9c74-e46938d1cc02', '25', 'E2ETestMedicine', 'E2ETestGeneric', 'BAT-493', '2027-07-06', 23, 107.00, 1, '2026-06-08 19:30:00'),
('32340e46-5c2a-5d02-bc18-5aa543634794', '25', 'Cozaar 50mg', 'Losartan Potassium (Cozaar)', 'BAT-493', '2027-07-06', 23, 87.00, 0, '2026-06-08 19:30:00'),
('c695b5c2-4b8f-5b93-aa89-060107c4cc34', '25', 'Pecoribright', 'OCR Extracted', 'BAT-493', '2027-07-06', 23, 42.00, 0, '2026-06-08 19:30:00'),
('574f5751-0261-56c1-958d-b1b407c5621f', '25', 'Venuson Compression Stocking', 'OCR Extracted', 'BAT-493', '2027-07-06', 23, 180.00, 0, '2026-06-08 19:30:00'),
('28fb8454-ad49-5131-978b-974de664e5b3', '25', 'Venusen Compression Stocking Class II, XL (Below Knee, Open Toe)', 'OCR Extracted', 'BAT-493', '2027-07-06', 23, 180.00, 0, '2026-06-08 19:30:00'),
('555b463b-e5c4-535f-8356-e63e85f1c5c8', '25', 'Venusen Compression Stocking (Below Knee, Open Toe)', 'OCR Extracted', 'BAT-493', '2027-07-06', 23, 180.00, 1, '2026-06-08 19:30:00'),
('91513e56-e979-5303-ae8a-1fac1922c2f5', '25', 'Gluonorm', 'OCR Extracted', 'BAT-493', '2027-07-06', 23, 113.00, 1, '2026-06-08 19:30:00'),
('49d7ca7c-8d0f-52c7-8a76-c1287d009eeb', '25', 'Furamil', 'OCR Extracted', 'BAT-493', '2027-07-06', 23, 29.00, 0, '2026-06-08 19:30:00'),
('88d75b4d-31e0-581e-b9ea-263617915e93', '25', 'Jivomed', 'OCR Extracted', 'BAT-493', '2027-07-06', 23, 74.00, 0, '2026-06-08 19:30:00'),
('6dc0c3da-828b-5ca3-a498-bd6c98236626', '25', 'Thiopro', 'OCR Extracted', 'BAT-493', '2027-07-06', 23, 110.00, 1, '2026-06-08 19:30:00'),
('834f1f5f-d979-5019-a7f6-a7128f34d1d9', '25', 'Unresolved Medicine', 'OCR Extracted', 'BAT-493', '2027-07-06', 23, 34.00, 0, '2026-06-08 19:30:00'),
('ba7654eb-4e09-5d48-952c-8ee8e2a13298', '25', 'Conveniui', 'OCR Extracted', 'BAT-493', '2027-07-06', 23, 75.00, 1, '2026-06-08 19:30:00'),
('28b959e8-f8e6-5456-b1b8-6b9cfddc67ba', '25', 'Puravil', 'OCR Extracted', 'BAT-493', '2027-07-06', 23, 90.00, 1, '2026-06-08 19:30:00'),
('356b7e75-56d0-5406-b293-986d05009e86', '25', 'Convenlur', 'OCR Extracted', 'BAT-493', '2027-07-06', 23, 118.00, 0, '2026-06-08 19:30:00'),
('b696c8fd-9bfb-55c2-b204-e3cf2d538dfc', '26', 'Paracetamol', 'Acetaminophen', 'BAT-383', '2027-03-18', 33, 15.45, 0, '2026-06-08 19:30:00'),
('1b1c2623-179c-57fa-b68e-4a11c236de24', '26', 'Ibuprofen', 'Ibuprofen', 'BAT-383', '2027-03-18', 33, 22.66, 1, '2026-06-08 19:30:00'),
('89cb4c4b-3753-5ddb-b605-4debc7e2c994', '26', 'Amoxicillin', 'Amoxicillin', 'BAT-383', '2027-03-18', 33, 36.05, 1, '2026-06-08 19:30:00'),
('6b0fb584-5563-5f9c-87b2-fcd9b506cf63', '26', 'Ventolin', 'Salbutamol', 'BAT-383', '2027-03-18', 33, 33.99, 1, '2026-06-08 19:30:00'),
('ed67ce0c-0961-551e-b1b3-bb24f0761a1b', '26', 'Paracetamol 500mg', 'Acetaminophen', 'BAT-383', '2027-03-18', 33, 18.54, 1, '2026-06-08 19:30:00'),
('0e6fbd17-401b-540f-82ee-5e073cd23fb8', '26', 'Ibuprofen 400mg', 'Ibuprofen', 'BAT-383', '2027-03-18', 33, 26.78, 0, '2026-06-08 19:30:00'),
('9d2e41fa-8d3b-5877-9782-247f097baa1f', '26', 'Amoxicillin 500mg', 'Amoxicillin (Penicillin Antibiotic)', 'BAT-383', '2027-03-18', 33, 43.26, 1, '2026-06-08 19:30:00'),
('47c525e5-b0c0-5c0a-988e-d86d2c9871a8', '26', 'Azithromycin 500mg', 'Azithromycin', 'BAT-383', '2027-03-18', 33, 96.82, 1, '2026-06-08 19:30:00'),
('09a332ab-e422-5771-ada3-09195297b885', '26', 'Ciprofloxacin 500mg', 'Ciprofloxacin', 'BAT-383', '2027-03-18', 33, 51.50, 0, '2026-06-08 19:30:00'),
('0ecb7ae7-cd7b-5d77-b07d-83f5cc9a639a', '26', 'Doxycycline 100mg', 'Doxycycline', 'BAT-383', '2027-03-18', 33, 67.98, 0, '2026-06-08 19:30:00'),
('f24d310b-a015-5eec-976c-f3ca0b63a2d0', '26', 'Metformin 500mg', 'Metformin', 'BAT-383', '2027-03-18', 33, 25.75, 0, '2026-06-08 19:30:00'),
('bb5fa670-8dd5-559e-ae4e-91ff9d277e28', '26', 'Omeprazole 20mg', 'Omeprazole', 'BAT-383', '2027-03-18', 33, 104.03, 0, '2026-06-08 19:30:00'),
('3e4ff63a-b106-543f-8988-389b631d9426', '26', 'Lisinopril 10mg', 'Lisinopril', 'BAT-383', '2027-03-18', 33, 76.22, 1, '2026-06-08 19:30:00'),
('caffd244-4138-53f3-880a-5bda95023b8c', '26', 'Amlodipine 5mg', 'Amlodipine', 'BAT-383', '2027-03-18', 33, 114.33, 1, '2026-06-08 19:30:00'),
('207078e0-1cf5-56b9-bff8-0c80c4adb4ee', '26', 'Atorvastatin 20mg', 'Atorvastatin', 'BAT-383', '2027-03-18', 33, 43.26, 0, '2026-06-08 19:30:00'),
('cfb95d22-b404-5acb-89f0-2237b74cabc0', '26', 'Losartan 50mg', 'Losartan', 'BAT-383', '2027-03-18', 33, 136.99, 0, '2026-06-08 19:30:00'),
('522b6b76-1ccd-515e-b438-9d901a9afde1', '26', 'Gabapentin 300mg', 'Gabapentin', 'BAT-383', '2027-03-18', 33, 40.17, 1, '2026-06-08 19:30:00'),
('e697fbef-f5c6-54d4-bf49-0dc1482f44d5', '26', 'Tramadol 50mg', 'Tramadol', 'BAT-383', '2027-03-18', 33, 114.33, 0, '2026-06-08 19:30:00'),
('fd8aede6-7a16-5f58-bffb-f60a19ff252e', '26', 'Cetirizine 10mg', 'Cetirizine', 'BAT-383', '2027-03-18', 33, 28.84, 0, '2026-06-08 19:30:00'),
('93e1cafd-bb30-5235-8c8b-45e2ca747af1', '26', 'Loratadine 10mg', 'Loratadine', 'BAT-383', '2027-03-18', 33, 39.14, 1, '2026-06-08 19:30:00'),
('1c4902f5-2b81-5471-8223-227adceeff9e', '26', 'Fexofenadine 180mg', 'Fexofenadine', 'BAT-383', '2027-03-18', 33, 59.74, 1, '2026-06-08 19:30:00'),
('be151a87-f605-5ccc-aff5-3e4bde209dfe', '26', 'Prednisolone 5mg', 'Prednisolone', 'BAT-383', '2027-03-18', 33, 73.13, 1, '2026-06-08 19:30:00'),
('3e16f99d-85a8-58cd-8d44-9c51c44e6e87', '26', 'Dexamethasone 4mg', 'Dexamethasone', 'BAT-383', '2027-03-18', 33, 94.76, 0, '2026-06-08 19:30:00'),
('64235967-36b0-5fc4-9339-e62df5efa7c1', '26', 'Hydrochlorothiazide 25mg', 'HCTZ', 'BAT-383', '2027-03-18', 33, 61.80, 0, '2026-06-08 19:30:00'),
('3608666d-22ee-59eb-a1d5-c73b7ddde7c5', '26', 'Furosemide 40mg', 'Furosemide', 'BAT-383', '2027-03-18', 33, 100.94, 1, '2026-06-08 19:30:00'),
('64be98dc-a977-5bab-b2b2-8c7cf7254c95', '26', 'Spironolactone 25mg', 'Spironolactone', 'BAT-383', '2027-03-18', 33, 62.83, 1, '2026-06-08 19:30:00'),
('730b89c4-854f-546d-85eb-bd7afd9b18b4', '26', 'Warfarin 5mg', 'Warfarin', 'BAT-383', '2027-03-18', 33, 25.75, 1, '2026-06-08 19:30:00'),
('eee02e08-dd4e-5f8d-a446-afc7d3d6b7b5', '26', 'Aspirin 81mg', 'Aspirin', 'BAT-383', '2027-03-18', 33, 12.36, 0, '2026-06-08 19:30:00'),
('57ebe26e-561a-59df-884c-1042ab2f9340', '26', 'Clopidogrel 75mg', 'Clopidogrel', 'BAT-383', '2027-03-18', 33, 25.75, 1, '2026-06-08 19:30:00'),
('8036f7c7-8561-5fab-88db-790456af09de', '26', 'Digoxin 0.25mg', 'Digoxin', 'BAT-383', '2027-03-18', 33, 25.75, 0, '2026-06-08 19:30:00'),
('0478bc12-7c12-5c97-b08f-bb4b72a2f0e7', '26', 'Levothyroxine 100mcg', 'Levothyroxine', 'BAT-383', '2027-03-18', 33, 136.99, 1, '2026-06-08 19:30:00'),
('8e088ee2-f868-594e-a171-4033bdd23010', '26', 'Insulin Aspart', 'Insulin Aspart', 'BAT-383', '2027-03-18', 33, 38.11, 0, '2026-06-08 19:30:00'),
('f75c3105-2e32-59c5-b2d4-f397fdac74bc', '26', 'Metronidazole 500mg', 'Metronidazole', 'BAT-383', '2027-03-18', 33, 22.66, 0, '2026-06-08 19:30:00'),
('a0cd1ed3-a770-5d0c-8b8f-76228b9adaa9', '26', 'Fluconazole 150mg', 'Fluconazole', 'BAT-383', '2027-03-18', 33, 150.38, 1, '2026-06-08 19:30:00'),
('6a0a9e23-1aaf-5ac2-8ad8-038bd7804385', '26', 'Acyclovir 400mg', 'Acyclovir', 'BAT-383', '2027-03-18', 33, 19.57, 1, '2026-06-08 19:30:00'),
('38050200-8f1c-5151-a1a5-fb97af83e906', '26', 'Clindamycin 300mg', 'Clindamycin', 'BAT-383', '2027-03-18', 33, 26.78, 0, '2026-06-08 19:30:00'),
('ac084acd-684a-5fd8-ab99-fcc1997b80e4', '26', 'Cephalexin 500mg', 'Cephalexin', 'BAT-383', '2027-03-18', 33, 15.45, 1, '2026-06-08 19:30:00'),
('dad86a6c-d1dd-5877-b8b8-a07a26439579', '26', 'Nitrofurantoin 100mg', 'Nitrofurantoin', 'BAT-383', '2027-03-18', 33, 37.08, 0, '2026-06-08 19:30:00'),
('a5674db0-5e63-5154-92d9-44e5bfdb9658', '26', 'Albuterol Inhaler', 'Salbutamol', 'BAT-383', '2027-03-18', 33, 130.81, 0, '2026-06-08 19:30:00'),
('55ab7bd8-9396-5136-b97d-774788180f4c', '26', 'Fluticasone Inhaler', 'Fluticasone', 'BAT-383', '2027-03-18', 33, 152.44, 0, '2026-06-08 19:30:00'),
('f2139935-b622-5a06-8945-65a39706b5fd', '26', 'Montelukast 10mg', 'Montelukast', 'BAT-383', '2027-03-18', 33, 45.32, 1, '2026-06-08 19:30:00'),
('ccc281c0-fd10-5092-b84d-e62741f8748e', '26', 'Esomeprazole 40mg', 'Esomeprazole', 'BAT-383', '2027-03-18', 33, 123.60, 0, '2026-06-08 19:30:00'),
('ca06303e-887b-54ef-a1ce-3b0e995d10a3', '26', 'Pantoprazole 40mg', 'Pantoprazole', 'BAT-383', '2027-03-18', 33, 24.72, 0, '2026-06-08 19:30:00'),
('5889d321-5523-586c-8bc7-a879c3cbb598', '26', 'Ranitidine 150mg', 'Ranitidine', 'BAT-383', '2027-03-18', 33, 28.84, 0, '2026-06-08 19:30:00'),
('930eca08-3b5b-51ad-b615-6c66292c381d', '26', 'Panadol Extra 500mg', 'Paracetamol + Caffeine', 'BAT-383', '2027-03-18', 33, 25.75, 1, '2026-06-08 19:30:00'),
('34cb48ba-6158-5da0-8fbd-089b8d2e83a1', '26', 'Panadol Cold & Flu', 'Paracetamol + Pseudoephedrine', 'BAT-383', '2027-03-18', 33, 28.84, 1, '2026-06-08 19:30:00'),
('6a0498a3-da81-54a5-8de1-42d79ebb8298', '26', 'Catafast 50mg', 'Diclofenac Potassium', 'BAT-383', '2027-03-18', 33, 39.14, 1, '2026-06-08 19:30:00'),
('776b6205-81ae-5d40-a583-ed2ff6902e05', '26', 'Voltaren 75mg', 'Diclofenac Sodium', 'BAT-383', '2027-03-18', 33, 49.44, 0, '2026-06-08 19:30:00'),
('12ed3ab3-8c39-5fe2-99ee-b1d1e8323614', '26', 'Mortal 400mg', 'Ibuprofen', 'BAT-383', '2027-03-18', 33, 59.74, 1, '2026-06-08 19:30:00'),
('12bd7316-fe7f-5415-bddd-399889f4677e', '26', 'Brufen 600mg', 'Ibuprofen', 'BAT-383', '2027-03-18', 33, 32.96, 1, '2026-06-08 19:30:00'),
('2e7b4247-cf5c-5932-ac78-92f60f16f337', '26', 'Amoxil 500mg', 'Amoxicillin', 'BAT-383', '2027-03-18', 33, 46.35, 1, '2026-06-08 19:30:00'),
('8c1129ff-6fc7-522b-8cd5-f5696d978450', '26', 'Augmentin 1g', 'Amoxicillin + Clavulanic acid', 'BAT-383', '2027-03-18', 33, 97.85, 1, '2026-06-08 19:30:00'),
('be6ca388-d440-5b82-9e24-762305f7bfc6', '26', 'Ciprinol 500mg', 'Ciprofloxacin', 'BAT-383', '2027-03-18', 33, 131.84, 1, '2026-06-08 19:30:00'),
('32d3e827-d4a4-50b1-9a71-fa2fbec81ea6', '26', 'Zithromax 500mg', 'Azithromycin', 'BAT-383', '2027-03-18', 33, 119.48, 0, '2026-06-08 19:30:00'),
('c6862f67-746d-5e99-9102-8a6f3a491510', '26', 'Flagyl 500mg', 'Metronidazole', 'BAT-383', '2027-03-18', 33, 24.72, 0, '2026-06-08 19:30:00'),
('9eb690e6-c8d5-59da-86d9-ecc1060b681c', '26', 'Rocephin 1g', 'Ceftriaxone', 'BAT-383', '2027-03-18', 33, 122.57, 1, '2026-06-08 19:30:00'),
('cd91596a-5353-5c79-b3dc-6459b2db53b6', '26', 'Tavanic 500mg', 'Levofloxacin', 'BAT-383', '2027-03-18', 33, 120.51, 0, '2026-06-08 19:30:00'),
('de300273-0efa-57c9-85f1-81ef9e06ee53', '26', 'Cravit 500mg', 'Levofloxacin', 'BAT-383', '2027-03-18', 33, 29.87, 1, '2026-06-08 19:30:00'),
('af4a7416-d425-5442-a270-5f6ebe956e3e', '26', 'Glucophage 500mg', 'Metformin', 'BAT-383', '2027-03-18', 33, 141.11, 1, '2026-06-08 19:30:00'),
('746e3413-5547-5d25-9f5d-90a1fd3bab93', '26', 'Glucophage XR 750mg', 'Metformin Extended Release', 'BAT-383', '2027-03-18', 33, 144.20, 1, '2026-06-08 19:30:00'),
('be72de49-a0a0-569a-84a7-a7c88ed4b4b7', '26', 'Diamicron 60mg', 'Gliclazide', 'BAT-383', '2027-03-18', 33, 19.57, 0, '2026-06-08 19:30:00'),
('8c784e18-1a93-590e-997a-303c315e76ac', '26', 'Januvia 100mg', 'Sitagliptin', 'BAT-383', '2027-03-18', 33, 144.20, 1, '2026-06-08 19:30:00'),
('db1d738c-22a3-5a66-b0ba-cc54bc5dbee2', '26', 'Antinal 400mg', 'Nifuroxazide', 'BAT-383', '2027-03-18', 33, 59.74, 0, '2026-06-08 19:30:00'),
('c1f3f4a5-5b96-5294-91c6-fd6a2cd174a0', '26', 'Entocid', 'Bismuth Subsalicylate', 'BAT-383', '2027-03-18', 33, 32.96, 0, '2026-06-08 19:30:00'),
('0dce71f2-ddd9-5355-9c81-6c122afe9e0d', '26', 'Spasmex 20mg', 'Mebeverine', 'BAT-383', '2027-03-18', 33, 17.51, 1, '2026-06-08 19:30:00'),
('8855154e-e77a-55da-a2b3-9fd134aa1e53', '26', 'Buscopan 10mg', 'Hyoscine Butylbromide', 'BAT-383', '2027-03-18', 33, 25.75, 0, '2026-06-08 19:30:00'),
('2cae1dc3-93c3-5400-915a-8545b46bba1c', '26', 'Miconazole Cream', 'Miconazole', 'BAT-383', '2027-03-18', 33, 138.02, 0, '2026-06-08 19:30:00'),
('b6a92219-eb66-5fb0-a444-532d062813bb', '26', 'Canesten Cream', 'Clotrimazole', 'BAT-383', '2027-03-18', 33, 135.96, 1, '2026-06-08 19:30:00'),
('1e7df6d8-9040-51f5-8ab4-22575f3f0c0e', '26', 'Fucicort Cream', 'Fusidic Acid + Betamethasone', 'BAT-383', '2027-03-18', 33, 143.17, 1, '2026-06-08 19:30:00'),
('5a03b235-dbc2-5f8e-9521-37943690c638', '26', 'Kenacort Injection', 'Triamcinolone', 'BAT-383', '2027-03-18', 33, 129.78, 1, '2026-06-08 19:30:00'),
('5fa3cb9d-0539-5d74-b25a-fe011e0d8610', '26', 'Depo-Medrol Injection', 'Methylprednisolone', 'BAT-383', '2027-03-18', 33, 70.04, 1, '2026-06-08 19:30:00'),
('1227ea3d-9f7c-538d-8fc8-3486343d6134', '26', 'Hydrocortisone Cream 1%', 'Hydrocortisone', 'BAT-383', '2027-03-18', 33, 42.23, 1, '2026-06-08 19:30:00'),
('26ec84a9-516d-5049-889e-4ba78f2ca3ee', '26', 'Ebastel 10mg', 'Ebastine', 'BAT-383', '2027-03-18', 33, 37.08, 1, '2026-06-08 19:30:00'),
('c12033d5-d863-53a5-98e4-dadfb5a98710', '26', 'Telfast 180mg', 'Fexofenadine', 'BAT-383', '2027-03-18', 33, 66.95, 1, '2026-06-08 19:30:00'),
('77cbf6fa-7208-5798-b96a-da41a25d1b2b', '26', 'Zyrtec 10mg', 'Cetirizine Hydrochloride', 'BAT-383', '2027-03-18', 33, 36.05, 1, '2026-06-08 19:30:00'),
('7c85bad3-c07c-5b4a-9998-303cb4aaca5b', '26', 'Claritin 10mg', 'Loratadine', 'BAT-383', '2027-03-18', 33, 46.35, 0, '2026-06-08 19:30:00'),
('12ee40c2-b770-56aa-a69d-53a29c617858', '26', 'Rhinathiol 200mg', 'Carbocisteine', 'BAT-383', '2027-03-18', 33, 83.43, 1, '2026-06-08 19:30:00'),
('ca350d12-4273-52e7-a792-574f8e7e6f8c', '26', 'Solmucol 600mg', 'Acetylcysteine', 'BAT-383', '2027-03-18', 33, 109.18, 0, '2026-06-08 19:30:00'),
('a406a139-fa5f-5e4e-a6c5-b18de11d3f09', '26', 'Bisolvon 8mg', 'Bromhexine', 'BAT-383', '2027-03-18', 33, 127.72, 0, '2026-06-08 19:30:00'),
('c7cac46f-635d-5141-9299-4a0e0d326da9', '26', 'Ventolin Inhaler', 'Salbutamol', 'BAT-383', '2027-03-18', 33, 46.35, 1, '2026-06-08 19:30:00'),
('0d290400-6888-55ce-bb95-0ed97018cbc4', '26', 'Seretide Inhaler', 'Fluticasone + Salmeterol', 'BAT-383', '2027-03-18', 33, 100.94, 0, '2026-06-08 19:30:00'),
('928b3778-a2d0-5afe-ab2e-65c4cd738939', '26', 'Singulair 10mg', 'Montelukast', 'BAT-383', '2027-03-18', 33, 44.29, 1, '2026-06-08 19:30:00'),
('fdeeb5d1-2e3b-5e8e-a42a-d9efc0bb0af6', '26', 'Avamys Nasal Spray', 'Fluticasone Furoate', 'BAT-383', '2027-03-18', 33, 36.05, 1, '2026-06-08 19:30:00'),
('db7b5147-19e4-50b4-9f8b-de0b30c720fa', '26', 'Otrivin Nasal Spray', 'Xylometazoline', 'BAT-383', '2027-03-18', 33, 22.66, 0, '2026-06-08 19:30:00'),
('62584243-dda7-52ee-a768-b653489db6ff', '26', 'Conventu', 'Conventu', 'BAT-383', '2027-03-18', 33, 18.54, 1, '2026-06-08 19:30:00'),
('55a996ae-a1af-5576-ade1-33781c1f9feb', '26', 'Recoxibright', 'Etoricoxib', 'BAT-383', '2027-03-18', 33, 87.55, 0, '2026-06-08 19:30:00'),
('7630acc1-1329-5ed3-b028-151637ae3b6c', '26', 'Sulfox', 'Cetyl Myristoleate + Glucosamine + MSM', 'BAT-383', '2027-03-18', 33, 51.50, 0, '2026-06-08 19:30:00'),
('67e96def-e28d-5644-a9d2-fcfd197c7779', '26', 'Sulfora gel', 'Cetyl Myristoleate + Glucosamine + MSM', 'BAT-383', '2027-03-18', 33, 143.17, 0, '2026-06-08 19:30:00'),
('8a6eabfc-b917-538c-baa9-ebc4d2baffa7', '26', 'Random Drug 50mg', 'Random Drug 50mg', 'BAT-383', '2027-03-18', 33, 120.51, 0, '2026-06-08 19:30:00'),
('3411666d-c3cd-5a69-95b5-696804692f81', '26', 'Convenntu 100mg', 'Convenntu 100mg', 'BAT-383', '2027-03-18', 33, 123.60, 0, '2026-06-08 19:30:00'),
('1dd3a72e-5201-5bae-914b-86c1b196efa0', '26', 'Recoribright 90mg', 'Recoribright 90mg', 'BAT-383', '2027-03-18', 33, 53.56, 1, '2026-06-08 19:30:00'),
('b8554c1e-c47c-5f33-92e4-def879e6d710', '26', 'Sulfoa gel', 'Cetyl Myristoleate + Glucosamine + MSM', 'BAT-383', '2027-03-18', 33, 108.15, 1, '2026-06-08 19:30:00'),
('5e788458-0f99-512b-af78-9eef3e84f4b5', '26', 'Sulfiox gel', 'Sulfiox gel', 'BAT-383', '2027-03-18', 33, 49.44, 0, '2026-06-08 19:30:00'),
('abd36416-8cdc-544d-bb4e-7406840c7159', '26', 'Conventus', 'Conventus', 'BAT-383', '2027-03-18', 33, 147.29, 1, '2026-06-08 19:30:00'),
('e30c2056-4f23-59d3-87e2-e9810aa7326e', '26', 'Convenia 100mg', 'Convenia 100mg', 'BAT-383', '2027-03-18', 33, 120.51, 0, '2026-06-08 19:30:00'),
('0cc006ef-3a6c-5c31-8f86-c1fb8232d535', '26', 'TestMed3', 'TestMed3', 'BAT-383', '2027-03-18', 33, 54.59, 0, '2026-06-08 19:30:00'),
('2c1a5cd0-89d5-552d-aa4e-3e1812eb43d2', '26', 'Conventin 100mg', 'Gabapentin', 'BAT-383', '2027-03-18', 33, 72.10, 0, '2026-06-08 19:30:00'),
('cd97aefc-b6e2-5821-bf70-15e0119db35a', '26', 'Recoxibright 90mg', 'Etoricoxib', 'BAT-383', '2027-03-18', 33, 97.85, 0, '2026-06-08 19:30:00'),
('60108c84-481f-58af-80d0-a5566c9e0d23', '26', 'Sulfax Gel', 'Cetyl Myristoleate + Glucosamine + MSM', 'BAT-383', '2027-03-18', 33, 56.65, 0, '2026-06-08 19:30:00'),
('d2ff0534-3c6b-587f-b814-87c7c1d7d99a', '26', 'Venusen Compression Stocking (Class II, XL, Under-knee)', 'OCR Extracted', 'BAT-383', '2027-03-18', 33, 185.40, 1, '2026-06-08 19:30:00'),
('f80abaa4-cec2-547f-8bbd-414106c6d06c', '26', 'Venusen Medical Compression Stockings (Below Knee)', 'OCR Extracted', 'BAT-383', '2027-03-18', 33, 185.40, 0, '2026-06-08 19:30:00'),
('9f6578b6-3223-5709-8ed6-be753a83f60f', '26', 'Venusen Compression Stocking (Below Knee, Class II, XL)', 'OCR Extracted', 'BAT-383', '2027-03-18', 33, 185.40, 1, '2026-06-08 19:30:00'),
('fe09773f-1e54-5314-966c-3e841bab10ef', '26', 'NonExistent Medicine', 'OCR Extracted', 'BAT-383', '2027-03-18', 33, 140.08, 0, '2026-06-08 19:30:00'),
('cc30f844-cd3a-5b04-9702-cf422f0629de', '26', 'Venosen Compression Stockings (Below Knee, Class II, XL)', 'OCR Extracted', 'BAT-383', '2027-03-18', 33, 185.40, 0, '2026-06-08 19:30:00'),
('785405e3-f8eb-5219-aff4-23d397a6af3e', '26', 'Prescribed Items', 'OCR Extracted', 'BAT-383', '2027-03-18', 33, 70.04, 1, '2026-06-08 19:30:00'),
('9b4f7a22-60f9-5604-88d9-e521493d3b62', '26', 'Panadol Extra', 'Paracetamol + Caffeine', 'BAT-383', '2027-03-18', 33, 24.72, 0, '2026-06-08 19:30:00'),
('46aaaae1-ec66-5453-b886-0bd6152e05ec', '26', 'Solpadeine Active', 'Paracetamol + Caffeine + Codeine', 'BAT-383', '2027-03-18', 33, 20.60, 1, '2026-06-08 19:30:00'),
('b32432ec-6106-555b-81f6-3b7f2b50b88a', '26', 'Lipitor 20mg', 'Atorvastatin Calcium', 'BAT-383', '2027-03-18', 33, 134.93, 1, '2026-06-08 19:30:00'),
('3ab22a73-9b53-5496-a56d-e257fbdd77ab', '26', 'Nexium 40mg', 'Esomeprazole', 'BAT-383', '2027-03-18', 33, 87.55, 0, '2026-06-08 19:30:00'),
('71f21a1f-c156-5799-9b2c-da23d320d099', '26', 'Augmentin 1gm', 'Amoxicillin + Clavulanate Potassium', 'BAT-383', '2027-03-18', 33, 87.55, 1, '2026-06-08 19:30:00'),
('cb4f05f7-5ca3-5bf0-8bda-274d69615e8e', '26', 'Cataflam 50mg', 'Diclofenac Potassium', 'BAT-383', '2027-03-18', 33, 37.08, 0, '2026-06-08 19:30:00'),
('633e4366-b83d-5ac3-8f75-c7a599ee5884', '26', 'Flotac', 'OCR Extracted', 'BAT-383', '2027-03-18', 33, 65.92, 1, '2026-06-08 19:30:00'),
('5185a87d-705c-5e7c-a0a7-0d5a3be11fbe', '26', 'Duphaston', 'OCR Extracted', 'BAT-383', '2027-03-18', 33, 123.60, 1, '2026-06-08 19:30:00'),
('48c2f60f-7d7e-56b0-ba61-bb92812e07f7', '26', 'H Daben Capsule', 'OCR Extracted', 'BAT-383', '2027-03-18', 33, 52.53, 0, '2026-06-08 19:30:00'),
('48681598-e4ad-52db-81b6-ad1ef525826d', '26', 'MegaVera 120mg Test', 'OCR Extracted', 'BAT-383', '2027-03-18', 33, 26.78, 0, '2026-06-08 19:30:00'),
('c6436b6d-1cad-54da-8bce-a72adf9d9bb9', '26', 'Venesen Compression Stockings, Knee-high, Size XL, Class II', 'OCR Extracted', 'BAT-383', '2027-03-18', 33, 126.69, 1, '2026-06-08 19:30:00'),
('cc3976f1-1ef6-5c5a-b350-0b7262031e06', '26', 'E2ETestMedicine', 'E2ETestGeneric', 'BAT-383', '2027-03-18', 33, 110.21, 0, '2026-06-08 19:30:00'),
('19af21a0-248e-5c60-8b8c-7fa73e5d4b47', '26', 'Cozaar 50mg', 'Losartan Potassium (Cozaar)', 'BAT-383', '2027-03-18', 33, 89.61, 1, '2026-06-08 19:30:00'),
('195cd989-7413-57a8-b43f-4109db765ed9', '26', 'Pecoribright', 'OCR Extracted', 'BAT-383', '2027-03-18', 33, 43.26, 1, '2026-06-08 19:30:00'),
('1c026bdd-1f35-5e63-874b-56f9a6047827', '26', 'Venuson Compression Stocking', 'OCR Extracted', 'BAT-383', '2027-03-18', 33, 185.40, 0, '2026-06-08 19:30:00'),
('b135302a-ce6a-5f31-a3c0-998949c005df', '26', 'Venusen Compression Stocking Class II, XL (Below Knee, Open Toe)', 'OCR Extracted', 'BAT-383', '2027-03-18', 33, 185.40, 0, '2026-06-08 19:30:00'),
('82d8292e-da9d-5b69-9afc-5ed5b45fc82f', '26', 'Venusen Compression Stocking (Below Knee, Open Toe)', 'OCR Extracted', 'BAT-383', '2027-03-18', 33, 185.40, 1, '2026-06-08 19:30:00'),
('c57de6e4-36d0-5676-92f8-dd219e7579f8', '26', 'Gluonorm', 'OCR Extracted', 'BAT-383', '2027-03-18', 33, 116.39, 0, '2026-06-08 19:30:00'),
('20412c41-9a7d-5d43-bda6-2c6135e148f1', '26', 'Furamil', 'OCR Extracted', 'BAT-383', '2027-03-18', 33, 29.87, 0, '2026-06-08 19:30:00'),
('732a67f5-b57e-5ab0-8e58-76503af9bdf6', '26', 'Jivomed', 'OCR Extracted', 'BAT-383', '2027-03-18', 33, 76.22, 0, '2026-06-08 19:30:00'),
('d6971333-4f60-5866-98bc-e53285597b24', '26', 'Thiopro', 'OCR Extracted', 'BAT-383', '2027-03-18', 33, 113.30, 0, '2026-06-08 19:30:00'),
('3aaa2cbc-d81a-5024-abb6-6d99c3f773eb', '26', 'Unresolved Medicine', 'OCR Extracted', 'BAT-383', '2027-03-18', 33, 35.02, 0, '2026-06-08 19:30:00'),
('f2b84aaa-0001-57e1-bf08-708cad36419b', '26', 'Conveniui', 'OCR Extracted', 'BAT-383', '2027-03-18', 33, 77.25, 0, '2026-06-08 19:30:00'),
('5f8c7bf7-1a7f-5ecd-a8d8-a8ef585088ee', '26', 'Puravil', 'OCR Extracted', 'BAT-383', '2027-03-18', 33, 92.70, 1, '2026-06-08 19:30:00'),
('8ca5527f-b0b2-51de-adbb-b6f0e9b63d4f', '26', 'Convenlur', 'OCR Extracted', 'BAT-383', '2027-03-18', 33, 121.54, 1, '2026-06-08 19:30:00'),
('d51a95bc-98ce-5fdc-9bf2-bd276850f655', '27', 'Paracetamol', 'Acetaminophen', 'BAT-843', '2027-06-26', 43, 15.15, 0, '2026-06-08 19:30:00'),
('5c06699f-29e3-5b3f-abf2-887f560fcaf6', '27', 'Ibuprofen', 'Ibuprofen', 'BAT-843', '2027-06-26', 43, 22.22, 0, '2026-06-08 19:30:00'),
('bc61c17d-c81c-5f1d-845f-39beb578e29c', '27', 'Amoxicillin', 'Amoxicillin', 'BAT-843', '2027-06-26', 43, 35.35, 0, '2026-06-08 19:30:00'),
('df90a64a-3719-5134-8203-6e0e1530ed8d', '27', 'Ventolin', 'Salbutamol', 'BAT-843', '2027-06-26', 43, 33.33, 0, '2026-06-08 19:30:00'),
('ec07bffa-60f1-57f1-be24-86c6193fd902', '27', 'Paracetamol 500mg', 'Acetaminophen', 'BAT-843', '2027-06-26', 43, 18.18, 1, '2026-06-08 19:30:00'),
('c795727d-ab90-5743-ae00-1797bbbfd9c3', '27', 'Ibuprofen 400mg', 'Ibuprofen', 'BAT-843', '2027-06-26', 43, 26.26, 1, '2026-06-08 19:30:00'),
('bd744cc5-45f7-5590-b5bf-0074c516bd83', '27', 'Amoxicillin 500mg', 'Amoxicillin (Penicillin Antibiotic)', 'BAT-843', '2027-06-26', 43, 42.42, 0, '2026-06-08 19:30:00'),
('8de511ff-402a-5e07-92ee-a1b58b29f0b8', '27', 'Azithromycin 500mg', 'Azithromycin', 'BAT-843', '2027-06-26', 43, 94.94, 0, '2026-06-08 19:30:00'),
('037668b0-000b-5d19-bdab-0d7a475a6678', '27', 'Ciprofloxacin 500mg', 'Ciprofloxacin', 'BAT-843', '2027-06-26', 43, 50.50, 0, '2026-06-08 19:30:00'),
('6da71305-6c4f-5bfa-a1fc-b6363abe4f1e', '27', 'Doxycycline 100mg', 'Doxycycline', 'BAT-843', '2027-06-26', 43, 66.66, 1, '2026-06-08 19:30:00'),
('d85ce150-306f-5bf1-8b14-7eae3f81e2e3', '27', 'Metformin 500mg', 'Metformin', 'BAT-843', '2027-06-26', 43, 25.25, 0, '2026-06-08 19:30:00'),
('93aabdd1-93f5-5d34-b252-0bcc2d673528', '27', 'Omeprazole 20mg', 'Omeprazole', 'BAT-843', '2027-06-26', 43, 102.01, 0, '2026-06-08 19:30:00'),
('fed22140-5191-5010-9481-b64f2b3ca6af', '27', 'Lisinopril 10mg', 'Lisinopril', 'BAT-843', '2027-06-26', 43, 74.74, 1, '2026-06-08 19:30:00'),
('3242fe05-84b6-5884-bbe5-27655fba2e2d', '27', 'Amlodipine 5mg', 'Amlodipine', 'BAT-843', '2027-06-26', 43, 112.11, 0, '2026-06-08 19:30:00'),
('596a7167-6b78-51d2-a574-ef84ce8448f3', '27', 'Atorvastatin 20mg', 'Atorvastatin', 'BAT-843', '2027-06-26', 43, 42.42, 1, '2026-06-08 19:30:00'),
('236799d3-5296-5a44-9cf7-ba4752c2125a', '27', 'Losartan 50mg', 'Losartan', 'BAT-843', '2027-06-26', 43, 134.33, 1, '2026-06-08 19:30:00'),
('db2f62f5-c2ae-5ef5-8d90-3d4a2913a612', '27', 'Gabapentin 300mg', 'Gabapentin', 'BAT-843', '2027-06-26', 43, 39.39, 1, '2026-06-08 19:30:00'),
('6c3524b6-a220-56b2-a997-6b640d79bd85', '27', 'Tramadol 50mg', 'Tramadol', 'BAT-843', '2027-06-26', 43, 112.11, 1, '2026-06-08 19:30:00'),
('32579501-7d24-58cb-b7ef-220660fedf50', '27', 'Cetirizine 10mg', 'Cetirizine', 'BAT-843', '2027-06-26', 43, 28.28, 1, '2026-06-08 19:30:00'),
('bb486cd1-f9d1-5b37-bea4-d09a99acb3d8', '27', 'Loratadine 10mg', 'Loratadine', 'BAT-843', '2027-06-26', 43, 38.38, 0, '2026-06-08 19:30:00'),
('4dc1b898-1203-5dbe-868b-6783339cff59', '27', 'Fexofenadine 180mg', 'Fexofenadine', 'BAT-843', '2027-06-26', 43, 58.58, 0, '2026-06-08 19:30:00'),
('e74d0b81-4833-59bb-b007-002e22791097', '27', 'Prednisolone 5mg', 'Prednisolone', 'BAT-843', '2027-06-26', 43, 71.71, 0, '2026-06-08 19:30:00'),
('970a246f-9b26-5c0a-933d-fc3b2ec411e8', '27', 'Dexamethasone 4mg', 'Dexamethasone', 'BAT-843', '2027-06-26', 43, 92.92, 1, '2026-06-08 19:30:00'),
('5950f2f0-6193-5e3a-9637-e8fbac2a7a9d', '27', 'Hydrochlorothiazide 25mg', 'HCTZ', 'BAT-843', '2027-06-26', 43, 60.60, 1, '2026-06-08 19:30:00'),
('00b96bd1-6b32-5674-a118-49da2824ec3e', '27', 'Furosemide 40mg', 'Furosemide', 'BAT-843', '2027-06-26', 43, 98.98, 1, '2026-06-08 19:30:00'),
('2b769541-a231-5199-8731-d0df2efde07a', '27', 'Spironolactone 25mg', 'Spironolactone', 'BAT-843', '2027-06-26', 43, 61.61, 1, '2026-06-08 19:30:00'),
('427f5101-5d2e-5f5e-acc4-6252aefb64d5', '27', 'Warfarin 5mg', 'Warfarin', 'BAT-843', '2027-06-26', 43, 25.25, 1, '2026-06-08 19:30:00'),
('a3304813-ab2a-5d45-a933-8c43d1462497', '27', 'Aspirin 81mg', 'Aspirin', 'BAT-843', '2027-06-26', 43, 12.12, 0, '2026-06-08 19:30:00'),
('471d6773-fb84-5456-8a18-846e3247a138', '27', 'Clopidogrel 75mg', 'Clopidogrel', 'BAT-843', '2027-06-26', 43, 25.25, 1, '2026-06-08 19:30:00'),
('ee74782c-71e1-515f-98cc-20db5192a628', '27', 'Digoxin 0.25mg', 'Digoxin', 'BAT-843', '2027-06-26', 43, 25.25, 0, '2026-06-08 19:30:00'),
('a660c081-1f9d-5400-8337-7ea5095ed2d4', '27', 'Levothyroxine 100mcg', 'Levothyroxine', 'BAT-843', '2027-06-26', 43, 134.33, 1, '2026-06-08 19:30:00'),
('9f0543cd-8e3c-5213-9f4f-457c477863ed', '27', 'Insulin Aspart', 'Insulin Aspart', 'BAT-843', '2027-06-26', 43, 37.37, 1, '2026-06-08 19:30:00'),
('8fd1baaa-e163-592f-8b9c-92abf8fb5956', '27', 'Metronidazole 500mg', 'Metronidazole', 'BAT-843', '2027-06-26', 43, 22.22, 0, '2026-06-08 19:30:00'),
('15b559f2-180d-5f06-9289-59837a28689a', '27', 'Fluconazole 150mg', 'Fluconazole', 'BAT-843', '2027-06-26', 43, 147.46, 1, '2026-06-08 19:30:00'),
('d86707d1-ca75-5f76-97e0-bdbef5b4c54d', '27', 'Acyclovir 400mg', 'Acyclovir', 'BAT-843', '2027-06-26', 43, 19.19, 1, '2026-06-08 19:30:00'),
('2a97779b-f3ec-57c1-9cd9-ef7e286af52a', '27', 'Clindamycin 300mg', 'Clindamycin', 'BAT-843', '2027-06-26', 43, 26.26, 1, '2026-06-08 19:30:00'),
('23803d4c-1524-56e9-8bbc-d806c2d619ec', '27', 'Cephalexin 500mg', 'Cephalexin', 'BAT-843', '2027-06-26', 43, 15.15, 1, '2026-06-08 19:30:00'),
('9a30eb20-23b1-5162-ac15-64fc9ae607a4', '27', 'Nitrofurantoin 100mg', 'Nitrofurantoin', 'BAT-843', '2027-06-26', 43, 36.36, 0, '2026-06-08 19:30:00'),
('99d2f78b-a6b0-5a45-b22c-8901403cad8c', '27', 'Albuterol Inhaler', 'Salbutamol', 'BAT-843', '2027-06-26', 43, 128.27, 1, '2026-06-08 19:30:00'),
('9f119636-de5e-5478-934e-da4d78f02062', '27', 'Fluticasone Inhaler', 'Fluticasone', 'BAT-843', '2027-06-26', 43, 149.48, 0, '2026-06-08 19:30:00'),
('eb76f181-a323-5e2b-91e0-3022fed527dc', '27', 'Montelukast 10mg', 'Montelukast', 'BAT-843', '2027-06-26', 43, 44.44, 0, '2026-06-08 19:30:00'),
('fcbbd4f6-4d75-51e9-a04a-5ef970ddb19d', '27', 'Esomeprazole 40mg', 'Esomeprazole', 'BAT-843', '2027-06-26', 43, 121.20, 1, '2026-06-08 19:30:00'),
('3576883c-6041-5a40-b255-9f35a591975f', '27', 'Pantoprazole 40mg', 'Pantoprazole', 'BAT-843', '2027-06-26', 43, 24.24, 0, '2026-06-08 19:30:00'),
('2aa4395c-baf4-54c3-a529-c4d4de2023ef', '27', 'Ranitidine 150mg', 'Ranitidine', 'BAT-843', '2027-06-26', 43, 28.28, 0, '2026-06-08 19:30:00'),
('a7281ce0-c768-5ca4-89f3-c8845b534ac4', '27', 'Panadol Extra 500mg', 'Paracetamol + Caffeine', 'BAT-843', '2027-06-26', 43, 25.25, 1, '2026-06-08 19:30:00'),
('bb29d4cd-aae0-5af7-ab02-6a41776d8f4c', '27', 'Panadol Cold & Flu', 'Paracetamol + Pseudoephedrine', 'BAT-843', '2027-06-26', 43, 28.28, 0, '2026-06-08 19:30:00'),
('dc5008ed-cd94-5d07-ac91-0a0ef1f90755', '27', 'Catafast 50mg', 'Diclofenac Potassium', 'BAT-843', '2027-06-26', 43, 38.38, 0, '2026-06-08 19:30:00'),
('7a1cf61c-f189-5f55-865c-c81b26982995', '27', 'Voltaren 75mg', 'Diclofenac Sodium', 'BAT-843', '2027-06-26', 43, 48.48, 0, '2026-06-08 19:30:00'),
('a9cadb3a-0144-5144-ae29-1f6f3b54059f', '27', 'Mortal 400mg', 'Ibuprofen', 'BAT-843', '2027-06-26', 43, 58.58, 1, '2026-06-08 19:30:00'),
('c86e90d7-28fd-5986-9771-6ab729790a82', '27', 'Brufen 600mg', 'Ibuprofen', 'BAT-843', '2027-06-26', 43, 32.32, 0, '2026-06-08 19:30:00'),
('e78261cd-e8b2-5286-8b7e-86b6782641dc', '27', 'Amoxil 500mg', 'Amoxicillin', 'BAT-843', '2027-06-26', 43, 45.45, 1, '2026-06-08 19:30:00'),
('67082b3b-9d89-5c68-b41c-125c6777c3bf', '27', 'Augmentin 1g', 'Amoxicillin + Clavulanic acid', 'BAT-843', '2027-06-26', 43, 95.95, 1, '2026-06-08 19:30:00'),
('b76ba0ed-7a23-5efd-8f35-7401c30f929c', '27', 'Ciprinol 500mg', 'Ciprofloxacin', 'BAT-843', '2027-06-26', 43, 129.28, 1, '2026-06-08 19:30:00'),
('70bee1aa-107a-5be2-a059-0e290d85287b', '27', 'Zithromax 500mg', 'Azithromycin', 'BAT-843', '2027-06-26', 43, 117.16, 0, '2026-06-08 19:30:00'),
('0cc0dedd-36ae-58f7-a386-a6c23692a274', '27', 'Flagyl 500mg', 'Metronidazole', 'BAT-843', '2027-06-26', 43, 24.24, 0, '2026-06-08 19:30:00'),
('11d300cb-b44d-5abd-b17b-57c9c589b3ea', '27', 'Rocephin 1g', 'Ceftriaxone', 'BAT-843', '2027-06-26', 43, 120.19, 1, '2026-06-08 19:30:00'),
('3615c861-4ace-51ec-aa7e-e3dd20bcd3ba', '27', 'Tavanic 500mg', 'Levofloxacin', 'BAT-843', '2027-06-26', 43, 118.17, 0, '2026-06-08 19:30:00'),
('6eb9562c-2d50-5bde-8666-5500e23abf3b', '27', 'Cravit 500mg', 'Levofloxacin', 'BAT-843', '2027-06-26', 43, 29.29, 1, '2026-06-08 19:30:00'),
('de12536e-d5fd-5ce7-9c3c-f7e09f0ddd2a', '27', 'Glucophage 500mg', 'Metformin', 'BAT-843', '2027-06-26', 43, 138.37, 1, '2026-06-08 19:30:00'),
('65c8b371-1593-5116-ad8e-259c1125805d', '27', 'Glucophage XR 750mg', 'Metformin Extended Release', 'BAT-843', '2027-06-26', 43, 141.40, 1, '2026-06-08 19:30:00'),
('7a9a3a4d-a3ae-5048-b6a7-f79cd313c6ee', '27', 'Diamicron 60mg', 'Gliclazide', 'BAT-843', '2027-06-26', 43, 19.19, 0, '2026-06-08 19:30:00'),
('16be6e0a-4a21-5e3b-9592-58b9c81bcc8b', '27', 'Januvia 100mg', 'Sitagliptin', 'BAT-843', '2027-06-26', 43, 141.40, 0, '2026-06-08 19:30:00'),
('6b94294e-5314-5135-9fe6-dda4daeca4b1', '27', 'Antinal 400mg', 'Nifuroxazide', 'BAT-843', '2027-06-26', 43, 58.58, 0, '2026-06-08 19:30:00'),
('46442d2b-378c-5542-9627-1eb70cf1bb96', '27', 'Entocid', 'Bismuth Subsalicylate', 'BAT-843', '2027-06-26', 43, 32.32, 0, '2026-06-08 19:30:00'),
('1ec2eff4-eead-5a7e-b96f-94d8580834d8', '27', 'Spasmex 20mg', 'Mebeverine', 'BAT-843', '2027-06-26', 43, 17.17, 0, '2026-06-08 19:30:00'),
('8d3b0ca0-3e39-592b-81ea-68122bc581f4', '27', 'Buscopan 10mg', 'Hyoscine Butylbromide', 'BAT-843', '2027-06-26', 43, 25.25, 0, '2026-06-08 19:30:00'),
('e432fc12-8d7e-5c8e-9f21-82ecd18480b0', '27', 'Miconazole Cream', 'Miconazole', 'BAT-843', '2027-06-26', 43, 135.34, 0, '2026-06-08 19:30:00'),
('2fa7fa80-5800-56c4-8372-e1efc30d4ebc', '27', 'Canesten Cream', 'Clotrimazole', 'BAT-843', '2027-06-26', 43, 133.32, 1, '2026-06-08 19:30:00'),
('9b916731-6d5f-5cc6-a1e9-c9f0754bd4fe', '27', 'Fucicort Cream', 'Fusidic Acid + Betamethasone', 'BAT-843', '2027-06-26', 43, 140.39, 0, '2026-06-08 19:30:00'),
('f86d6a37-8f3c-504d-9a80-8c57070a4237', '27', 'Kenacort Injection', 'Triamcinolone', 'BAT-843', '2027-06-26', 43, 127.26, 1, '2026-06-08 19:30:00'),
('66ed5e04-ed51-5943-b969-1be784f38907', '27', 'Depo-Medrol Injection', 'Methylprednisolone', 'BAT-843', '2027-06-26', 43, 68.68, 0, '2026-06-08 19:30:00'),
('8056f500-03d8-5418-a0e1-abef157f762d', '27', 'Hydrocortisone Cream 1%', 'Hydrocortisone', 'BAT-843', '2027-06-26', 43, 41.41, 0, '2026-06-08 19:30:00'),
('491665e0-0099-5264-9a41-f2298896e912', '27', 'Ebastel 10mg', 'Ebastine', 'BAT-843', '2027-06-26', 43, 36.36, 0, '2026-06-08 19:30:00'),
('81d9c262-9b19-5a57-b2c1-d891df2fec00', '27', 'Telfast 180mg', 'Fexofenadine', 'BAT-843', '2027-06-26', 43, 65.65, 0, '2026-06-08 19:30:00'),
('5994f6f8-b47a-5671-a6a7-11c2327e3f8e', '27', 'Zyrtec 10mg', 'Cetirizine Hydrochloride', 'BAT-843', '2027-06-26', 43, 35.35, 0, '2026-06-08 19:30:00'),
('6a7ac8a2-6d99-54a9-b0bd-d561b7980c4a', '27', 'Claritin 10mg', 'Loratadine', 'BAT-843', '2027-06-26', 43, 45.45, 1, '2026-06-08 19:30:00'),
('1a6f6875-85af-5ca1-ac72-bdf147cec5e5', '27', 'Rhinathiol 200mg', 'Carbocisteine', 'BAT-843', '2027-06-26', 43, 81.81, 0, '2026-06-08 19:30:00'),
('24e53c1a-e39b-5c0d-bc51-e6c28acd3a64', '27', 'Solmucol 600mg', 'Acetylcysteine', 'BAT-843', '2027-06-26', 43, 107.06, 0, '2026-06-08 19:30:00'),
('6cb2f4c8-e3d3-5d8b-adbc-9a220e36127d', '27', 'Bisolvon 8mg', 'Bromhexine', 'BAT-843', '2027-06-26', 43, 125.24, 0, '2026-06-08 19:30:00'),
('11d6862c-8bcc-5933-9ad3-c3676a14fa52', '27', 'Ventolin Inhaler', 'Salbutamol', 'BAT-843', '2027-06-26', 43, 45.45, 1, '2026-06-08 19:30:00'),
('fd0a42b5-c7a6-587a-b449-2864a4fbb388', '27', 'Seretide Inhaler', 'Fluticasone + Salmeterol', 'BAT-843', '2027-06-26', 43, 98.98, 1, '2026-06-08 19:30:00'),
('a6762aa1-33af-50a8-8ebb-6932d5614238', '27', 'Singulair 10mg', 'Montelukast', 'BAT-843', '2027-06-26', 43, 43.43, 0, '2026-06-08 19:30:00'),
('ec70e07f-4136-5776-af8c-d6f2a418380f', '27', 'Avamys Nasal Spray', 'Fluticasone Furoate', 'BAT-843', '2027-06-26', 43, 35.35, 1, '2026-06-08 19:30:00'),
('3140c476-a504-59a5-af74-0cad934bd75f', '27', 'Otrivin Nasal Spray', 'Xylometazoline', 'BAT-843', '2027-06-26', 43, 22.22, 1, '2026-06-08 19:30:00'),
('4a2d12ed-cad0-5f96-99f3-8f67988f8fdf', '27', 'Conventu', 'Conventu', 'BAT-843', '2027-06-26', 43, 18.18, 1, '2026-06-08 19:30:00'),
('0564e29a-b05f-547e-9cfe-feb8b3638483', '27', 'Recoxibright', 'Etoricoxib', 'BAT-843', '2027-06-26', 43, 85.85, 1, '2026-06-08 19:30:00'),
('5d91103f-bec3-57db-9446-48a16931d553', '27', 'Sulfox', 'Cetyl Myristoleate + Glucosamine + MSM', 'BAT-843', '2027-06-26', 43, 50.50, 0, '2026-06-08 19:30:00'),
('a92b5e4d-419b-532e-9336-0dcc855d425f', '27', 'Sulfora gel', 'Cetyl Myristoleate + Glucosamine + MSM', 'BAT-843', '2027-06-26', 43, 140.39, 1, '2026-06-08 19:30:00'),
('60c251f3-dedc-52ce-a631-9a10a204258d', '27', 'Random Drug 50mg', 'Random Drug 50mg', 'BAT-843', '2027-06-26', 43, 118.17, 0, '2026-06-08 19:30:00'),
('ed6d73a1-6b19-589e-b04a-5de0fe9befc1', '27', 'Convenntu 100mg', 'Convenntu 100mg', 'BAT-843', '2027-06-26', 43, 121.20, 0, '2026-06-08 19:30:00'),
('e137b628-e356-52c9-9cd0-bcd0b77d4793', '27', 'Recoribright 90mg', 'Recoribright 90mg', 'BAT-843', '2027-06-26', 43, 52.52, 1, '2026-06-08 19:30:00'),
('ace16902-9a5d-5df6-b0a9-784f7e80402f', '27', 'Sulfoa gel', 'Cetyl Myristoleate + Glucosamine + MSM', 'BAT-843', '2027-06-26', 43, 106.05, 1, '2026-06-08 19:30:00'),
('586a9c8a-d499-5c5f-9865-b702fda1c690', '27', 'Sulfiox gel', 'Sulfiox gel', 'BAT-843', '2027-06-26', 43, 48.48, 1, '2026-06-08 19:30:00'),
('3721ab02-1bcf-5e8c-863a-11bdbca217c8', '27', 'Conventus', 'Conventus', 'BAT-843', '2027-06-26', 43, 144.43, 0, '2026-06-08 19:30:00'),
('d5e84bca-1086-57ee-b885-5a21f96c33a6', '27', 'Convenia 100mg', 'Convenia 100mg', 'BAT-843', '2027-06-26', 43, 118.17, 0, '2026-06-08 19:30:00'),
('46f819a8-e2e1-5e8f-9158-c57f35eb9c90', '27', 'TestMed3', 'TestMed3', 'BAT-843', '2027-06-26', 43, 53.53, 1, '2026-06-08 19:30:00'),
('64906159-01fd-5b72-8af9-d4d49790d8a7', '27', 'Conventin 100mg', 'Gabapentin', 'BAT-843', '2027-06-26', 43, 70.70, 1, '2026-06-08 19:30:00'),
('96d1fe69-daf2-55b8-a934-68a5a626a720', '27', 'Recoxibright 90mg', 'Etoricoxib', 'BAT-843', '2027-06-26', 43, 95.95, 1, '2026-06-08 19:30:00'),
('548f8430-979c-541c-9256-fe05249d2fee', '27', 'Sulfax Gel', 'Cetyl Myristoleate + Glucosamine + MSM', 'BAT-843', '2027-06-26', 43, 55.55, 1, '2026-06-08 19:30:00'),
('01d3c1f0-f519-5e8e-8840-c7fb34490e08', '27', 'Venusen Compression Stocking (Class II, XL, Under-knee)', 'OCR Extracted', 'BAT-843', '2027-06-26', 43, 181.80, 0, '2026-06-08 19:30:00'),
('069b175d-c5e4-5283-87f6-4521f172c19d', '27', 'Venusen Medical Compression Stockings (Below Knee)', 'OCR Extracted', 'BAT-843', '2027-06-26', 43, 181.80, 0, '2026-06-08 19:30:00'),
('808950ad-e2cb-5983-9f7a-6f45aab614ed', '27', 'Venusen Compression Stocking (Below Knee, Class II, XL)', 'OCR Extracted', 'BAT-843', '2027-06-26', 43, 181.80, 1, '2026-06-08 19:30:00'),
('ea3baf7e-a058-5a03-bed1-43371e0bbd39', '27', 'NonExistent Medicine', 'OCR Extracted', 'BAT-843', '2027-06-26', 43, 137.36, 1, '2026-06-08 19:30:00'),
('c9f062e9-5957-514d-b719-153b5769d6de', '27', 'Venosen Compression Stockings (Below Knee, Class II, XL)', 'OCR Extracted', 'BAT-843', '2027-06-26', 43, 181.80, 1, '2026-06-08 19:30:00'),
('e3db86a3-8cc8-51b2-9290-9ec1463234ec', '27', 'Prescribed Items', 'OCR Extracted', 'BAT-843', '2027-06-26', 43, 68.68, 0, '2026-06-08 19:30:00'),
('1839dfa9-0629-5694-b290-bd486974a29b', '27', 'Panadol Extra', 'Paracetamol + Caffeine', 'BAT-843', '2027-06-26', 43, 24.24, 0, '2026-06-08 19:30:00'),
('57378a81-ad72-5ac5-84d4-41dce1361c49', '27', 'Solpadeine Active', 'Paracetamol + Caffeine + Codeine', 'BAT-843', '2027-06-26', 43, 20.20, 1, '2026-06-08 19:30:00'),
('7aa86a4f-6878-547e-99ef-ec0f84cd6b24', '27', 'Lipitor 20mg', 'Atorvastatin Calcium', 'BAT-843', '2027-06-26', 43, 132.31, 1, '2026-06-08 19:30:00'),
('1b1bfd2f-140f-5724-9638-f1f97c91a929', '27', 'Nexium 40mg', 'Esomeprazole', 'BAT-843', '2027-06-26', 43, 85.85, 1, '2026-06-08 19:30:00'),
('9c1d9393-7e81-5840-b4d1-7bc3dcd91438', '27', 'Augmentin 1gm', 'Amoxicillin + Clavulanate Potassium', 'BAT-843', '2027-06-26', 43, 85.85, 0, '2026-06-08 19:30:00'),
('3d776b54-413c-5908-8071-b9fd6fb8ee53', '27', 'Cataflam 50mg', 'Diclofenac Potassium', 'BAT-843', '2027-06-26', 43, 36.36, 0, '2026-06-08 19:30:00'),
('2d1c7dc3-053d-5cac-b3f1-d7b77a0ced22', '27', 'Flotac', 'OCR Extracted', 'BAT-843', '2027-06-26', 43, 64.64, 0, '2026-06-08 19:30:00'),
('44ffa198-a90e-595d-bd6b-1460de733b3b', '27', 'Duphaston', 'OCR Extracted', 'BAT-843', '2027-06-26', 43, 121.20, 0, '2026-06-08 19:30:00'),
('31d61b81-dc3e-540a-9007-b8e2452826d2', '27', 'H Daben Capsule', 'OCR Extracted', 'BAT-843', '2027-06-26', 43, 51.51, 0, '2026-06-08 19:30:00'),
('ad7b34f7-1dc7-5559-bd74-283bd0e0dbea', '27', 'MegaVera 120mg Test', 'OCR Extracted', 'BAT-843', '2027-06-26', 43, 26.26, 1, '2026-06-08 19:30:00'),
('da80807c-068d-54cc-be4c-2f8760966bd1', '27', 'Venesen Compression Stockings, Knee-high, Size XL, Class II', 'OCR Extracted', 'BAT-843', '2027-06-26', 43, 124.23, 1, '2026-06-08 19:30:00'),
('ce94abdf-8246-52d8-aaaf-ec02dc093086', '27', 'E2ETestMedicine', 'E2ETestGeneric', 'BAT-843', '2027-06-26', 43, 108.07, 1, '2026-06-08 19:30:00'),
('50341215-298d-5a91-9ce0-4dd08e296999', '27', 'Cozaar 50mg', 'Losartan Potassium (Cozaar)', 'BAT-843', '2027-06-26', 43, 87.87, 0, '2026-06-08 19:30:00'),
('ccfb4f48-8a17-5af8-81a6-0bab9b958930', '27', 'Pecoribright', 'OCR Extracted', 'BAT-843', '2027-06-26', 43, 42.42, 1, '2026-06-08 19:30:00'),
('9fc0b3f8-9d57-5dd1-8217-17347ea0673f', '27', 'Venuson Compression Stocking', 'OCR Extracted', 'BAT-843', '2027-06-26', 43, 181.80, 0, '2026-06-08 19:30:00'),
('2481e912-61fe-5b67-ace2-adcb25650a04', '27', 'Venusen Compression Stocking Class II, XL (Below Knee, Open Toe)', 'OCR Extracted', 'BAT-843', '2027-06-26', 43, 181.80, 1, '2026-06-08 19:30:00'),
('1988203a-4935-5e1d-b782-9d59f1ceb7c3', '27', 'Venusen Compression Stocking (Below Knee, Open Toe)', 'OCR Extracted', 'BAT-843', '2027-06-26', 43, 181.80, 1, '2026-06-08 19:30:00'),
('2e442ef7-3240-5371-8a37-b72ca6c04a3b', '27', 'Gluonorm', 'OCR Extracted', 'BAT-843', '2027-06-26', 43, 114.13, 1, '2026-06-08 19:30:00'),
('dd3f373f-c4c6-5ef9-90db-75651f975df2', '27', 'Furamil', 'OCR Extracted', 'BAT-843', '2027-06-26', 43, 29.29, 1, '2026-06-08 19:30:00'),
('5ae9a49d-552a-5f6b-b873-5b1ce10962e6', '27', 'Jivomed', 'OCR Extracted', 'BAT-843', '2027-06-26', 43, 74.74, 0, '2026-06-08 19:30:00'),
('d80b0705-4246-5bcc-b012-02cc039a3859', '27', 'Thiopro', 'OCR Extracted', 'BAT-843', '2027-06-26', 43, 111.10, 0, '2026-06-08 19:30:00'),
('fea017a8-2649-50fc-ae3b-ed798cacc19f', '27', 'Unresolved Medicine', 'OCR Extracted', 'BAT-843', '2027-06-26', 43, 34.34, 0, '2026-06-08 19:30:00'),
('a0908d0a-5e12-5e46-b7f0-c7da759750aa', '27', 'Conveniui', 'OCR Extracted', 'BAT-843', '2027-06-26', 43, 75.75, 1, '2026-06-08 19:30:00'),
('05fd6fcb-add5-5449-872b-971d973d627c', '27', 'Puravil', 'OCR Extracted', 'BAT-843', '2027-06-26', 43, 90.90, 1, '2026-06-08 19:30:00'),
('6a6fe428-f2e8-5f10-98a0-31006d8a2cb8', '27', 'Convenlur', 'OCR Extracted', 'BAT-843', '2027-06-26', 43, 119.18, 0, '2026-06-08 19:30:00'),
('87e3a687-60e6-5530-b17f-e548efbcfaed', '28', 'Paracetamol', 'Acetaminophen', 'BAT-787', '2027-10-28', 47, 15.75, 1, '2026-06-08 19:30:00'),
('6399f3ff-834e-5049-8a49-50daa6230b7e', '28', 'Ibuprofen', 'Ibuprofen', 'BAT-787', '2027-10-28', 47, 23.10, 0, '2026-06-08 19:30:00'),
('496d8dc8-6e61-519c-ad77-38b1ccc3e27b', '28', 'Amoxicillin', 'Amoxicillin', 'BAT-787', '2027-10-28', 47, 36.75, 0, '2026-06-08 19:30:00'),
('683ffe7a-cd48-5f5a-9eb8-2d77d72fd344', '28', 'Ventolin', 'Salbutamol', 'BAT-787', '2027-10-28', 47, 34.65, 1, '2026-06-08 19:30:00'),
('5aed8331-492c-5b0e-a4e8-ede14e766422', '28', 'Paracetamol 500mg', 'Acetaminophen', 'BAT-787', '2027-10-28', 47, 18.90, 0, '2026-06-08 19:30:00'),
('94bcf3f0-41d7-5e04-aeaa-d65c2ef5f091', '28', 'Ibuprofen 400mg', 'Ibuprofen', 'BAT-787', '2027-10-28', 47, 27.30, 1, '2026-06-08 19:30:00'),
('73c211b5-9b5d-5f00-bab0-c0e02c020e9e', '28', 'Amoxicillin 500mg', 'Amoxicillin (Penicillin Antibiotic)', 'BAT-787', '2027-10-28', 47, 44.10, 0, '2026-06-08 19:30:00'),
('30b68bef-8326-500c-97e4-af7c892a345d', '28', 'Azithromycin 500mg', 'Azithromycin', 'BAT-787', '2027-10-28', 47, 98.70, 1, '2026-06-08 19:30:00'),
('65f0aa42-665e-58fa-b4e6-38a0fad757e8', '28', 'Ciprofloxacin 500mg', 'Ciprofloxacin', 'BAT-787', '2027-10-28', 47, 52.50, 0, '2026-06-08 19:30:00'),
('041e4e34-0edf-585a-b372-695e39e186ef', '28', 'Doxycycline 100mg', 'Doxycycline', 'BAT-787', '2027-10-28', 47, 69.30, 1, '2026-06-08 19:30:00'),
('f2a65eae-4f88-5de2-a670-792c95e91da4', '28', 'Metformin 500mg', 'Metformin', 'BAT-787', '2027-10-28', 47, 26.25, 1, '2026-06-08 19:30:00'),
('d9a94557-758f-51c1-8a81-c95e0ce4f249', '28', 'Omeprazole 20mg', 'Omeprazole', 'BAT-787', '2027-10-28', 47, 106.05, 0, '2026-06-08 19:30:00'),
('5e4badbd-420a-5872-9d27-d11dd9387b39', '28', 'Lisinopril 10mg', 'Lisinopril', 'BAT-787', '2027-10-28', 47, 77.70, 1, '2026-06-08 19:30:00'),
('0b2593c9-2960-5cad-b5d5-f33017525393', '28', 'Amlodipine 5mg', 'Amlodipine', 'BAT-787', '2027-10-28', 47, 116.55, 0, '2026-06-08 19:30:00'),
('9c6e1e87-5efa-54dd-90eb-9d278e9eb626', '28', 'Atorvastatin 20mg', 'Atorvastatin', 'BAT-787', '2027-10-28', 47, 44.10, 1, '2026-06-08 19:30:00'),
('423e3281-99dc-523f-8211-f4ace51bbf05', '28', 'Losartan 50mg', 'Losartan', 'BAT-787', '2027-10-28', 47, 139.65, 0, '2026-06-08 19:30:00'),
('61ac2f54-7df6-5af6-8175-4f216ff7a745', '28', 'Gabapentin 300mg', 'Gabapentin', 'BAT-787', '2027-10-28', 47, 40.95, 1, '2026-06-08 19:30:00'),
('3922d06f-17eb-5821-ab1c-24595190c4e2', '28', 'Tramadol 50mg', 'Tramadol', 'BAT-787', '2027-10-28', 47, 116.55, 0, '2026-06-08 19:30:00'),
('efee629e-50ca-5fc9-b523-674451da7ae6', '28', 'Cetirizine 10mg', 'Cetirizine', 'BAT-787', '2027-10-28', 47, 29.40, 0, '2026-06-08 19:30:00'),
('19d3c1b7-a5d1-5925-a601-9f9ec46d60e6', '28', 'Loratadine 10mg', 'Loratadine', 'BAT-787', '2027-10-28', 47, 39.90, 1, '2026-06-08 19:30:00'),
('6a664104-8505-51eb-afb6-45c391762b5e', '28', 'Fexofenadine 180mg', 'Fexofenadine', 'BAT-787', '2027-10-28', 47, 60.90, 0, '2026-06-08 19:30:00'),
('f0ef2a7b-0b4f-593e-81c3-f1204f1a42de', '28', 'Prednisolone 5mg', 'Prednisolone', 'BAT-787', '2027-10-28', 47, 74.55, 1, '2026-06-08 19:30:00'),
('8a2e88d0-56ae-579f-96d3-88631dfc720f', '28', 'Dexamethasone 4mg', 'Dexamethasone', 'BAT-787', '2027-10-28', 47, 96.60, 1, '2026-06-08 19:30:00'),
('129640a8-9513-5231-9fad-050dace3a030', '28', 'Hydrochlorothiazide 25mg', 'HCTZ', 'BAT-787', '2027-10-28', 47, 63.00, 1, '2026-06-08 19:30:00'),
('ac21fb23-f61f-5727-8ee3-ad294a2b9457', '28', 'Furosemide 40mg', 'Furosemide', 'BAT-787', '2027-10-28', 47, 102.90, 0, '2026-06-08 19:30:00'),
('bc775f7d-8e15-5b40-8289-b7c009a31a43', '28', 'Spironolactone 25mg', 'Spironolactone', 'BAT-787', '2027-10-28', 47, 64.05, 0, '2026-06-08 19:30:00'),
('19fa66e6-0e4a-5443-8d7e-f80f2c6e6bfe', '28', 'Warfarin 5mg', 'Warfarin', 'BAT-787', '2027-10-28', 47, 26.25, 1, '2026-06-08 19:30:00'),
('d6f16815-1e67-5f24-bb1d-b7b909d1b845', '28', 'Aspirin 81mg', 'Aspirin', 'BAT-787', '2027-10-28', 47, 12.60, 0, '2026-06-08 19:30:00'),
('aa0877b6-8a29-5adb-adf7-a618e2bbb9cf', '28', 'Clopidogrel 75mg', 'Clopidogrel', 'BAT-787', '2027-10-28', 47, 26.25, 1, '2026-06-08 19:30:00'),
('6bc4c1eb-2ac7-5a08-b2d1-7fb95b34cb73', '28', 'Digoxin 0.25mg', 'Digoxin', 'BAT-787', '2027-10-28', 47, 26.25, 0, '2026-06-08 19:30:00'),
('c761a5f8-5590-54c5-8ee1-ba413ea60a10', '28', 'Levothyroxine 100mcg', 'Levothyroxine', 'BAT-787', '2027-10-28', 47, 139.65, 0, '2026-06-08 19:30:00'),
('9e2c755a-69e3-50db-95bf-83b1e9b8f552', '28', 'Insulin Aspart', 'Insulin Aspart', 'BAT-787', '2027-10-28', 47, 38.85, 0, '2026-06-08 19:30:00'),
('1961660a-ffe1-5fcd-aee8-021cb819544b', '28', 'Metronidazole 500mg', 'Metronidazole', 'BAT-787', '2027-10-28', 47, 23.10, 0, '2026-06-08 19:30:00'),
('61edf069-5165-588a-bb58-4aa51e42a0aa', '28', 'Fluconazole 150mg', 'Fluconazole', 'BAT-787', '2027-10-28', 47, 153.30, 1, '2026-06-08 19:30:00'),
('985add36-8d32-588e-a13f-fc5d69f08b81', '28', 'Acyclovir 400mg', 'Acyclovir', 'BAT-787', '2027-10-28', 47, 19.95, 1, '2026-06-08 19:30:00'),
('e0dc9096-c33f-5976-b26b-2272e906b7b8', '28', 'Clindamycin 300mg', 'Clindamycin', 'BAT-787', '2027-10-28', 47, 27.30, 1, '2026-06-08 19:30:00'),
('6adde90a-b2f4-5401-bbae-586872b1c918', '28', 'Cephalexin 500mg', 'Cephalexin', 'BAT-787', '2027-10-28', 47, 15.75, 1, '2026-06-08 19:30:00'),
('f4d99101-9b67-52d9-aa03-08da92bea637', '28', 'Nitrofurantoin 100mg', 'Nitrofurantoin', 'BAT-787', '2027-10-28', 47, 37.80, 1, '2026-06-08 19:30:00'),
('071147de-2b2a-5bd6-a735-d93d718eb566', '28', 'Albuterol Inhaler', 'Salbutamol', 'BAT-787', '2027-10-28', 47, 133.35, 1, '2026-06-08 19:30:00'),
('5f786b26-7e0a-5fb8-aa87-3def563b29fa', '28', 'Fluticasone Inhaler', 'Fluticasone', 'BAT-787', '2027-10-28', 47, 155.40, 0, '2026-06-08 19:30:00'),
('3207c203-d27d-5d18-afec-dd53b5f313b3', '28', 'Montelukast 10mg', 'Montelukast', 'BAT-787', '2027-10-28', 47, 46.20, 0, '2026-06-08 19:30:00'),
('0d99d1e9-bd1d-5a41-8d29-58e10462f7d0', '28', 'Esomeprazole 40mg', 'Esomeprazole', 'BAT-787', '2027-10-28', 47, 126.00, 0, '2026-06-08 19:30:00'),
('1bf2f200-51b0-5950-b115-ad03beeffd14', '28', 'Pantoprazole 40mg', 'Pantoprazole', 'BAT-787', '2027-10-28', 47, 25.20, 1, '2026-06-08 19:30:00'),
('f8e46cce-8b36-543e-99c5-97faeec00622', '28', 'Ranitidine 150mg', 'Ranitidine', 'BAT-787', '2027-10-28', 47, 29.40, 0, '2026-06-08 19:30:00'),
('ca7a6014-3af5-5104-90ff-dca0b5e1797c', '28', 'Panadol Extra 500mg', 'Paracetamol + Caffeine', 'BAT-787', '2027-10-28', 47, 26.25, 0, '2026-06-08 19:30:00'),
('41fcb2d8-5cd6-5edf-b4f3-cf1b2e9512f5', '28', 'Panadol Cold & Flu', 'Paracetamol + Pseudoephedrine', 'BAT-787', '2027-10-28', 47, 29.40, 0, '2026-06-08 19:30:00'),
('089dface-2e24-5aee-bffa-0f85bd220b9f', '28', 'Catafast 50mg', 'Diclofenac Potassium', 'BAT-787', '2027-10-28', 47, 39.90, 0, '2026-06-08 19:30:00'),
('b44fa9c0-a0c7-5f8e-b56c-b0f5fffa82a8', '28', 'Voltaren 75mg', 'Diclofenac Sodium', 'BAT-787', '2027-10-28', 47, 50.40, 0, '2026-06-08 19:30:00'),
('81efd5a2-b0be-5be1-bbe5-eb5b57a94036', '28', 'Mortal 400mg', 'Ibuprofen', 'BAT-787', '2027-10-28', 47, 60.90, 0, '2026-06-08 19:30:00'),
('d3e6f4da-e0df-5225-89b9-21f0105da01f', '28', 'Brufen 600mg', 'Ibuprofen', 'BAT-787', '2027-10-28', 47, 33.60, 0, '2026-06-08 19:30:00'),
('66ab0ffa-1a50-5e87-afd5-f692def1ffbe', '28', 'Amoxil 500mg', 'Amoxicillin', 'BAT-787', '2027-10-28', 47, 47.25, 0, '2026-06-08 19:30:00'),
('96967e07-cea7-5dfd-9cdf-8e5f140f9238', '28', 'Augmentin 1g', 'Amoxicillin + Clavulanic acid', 'BAT-787', '2027-10-28', 47, 99.75, 1, '2026-06-08 19:30:00'),
('7556b236-6cb6-555b-9c46-789701e5736b', '28', 'Ciprinol 500mg', 'Ciprofloxacin', 'BAT-787', '2027-10-28', 47, 134.40, 1, '2026-06-08 19:30:00'),
('559b9a22-9893-5441-bafd-4a3ce5e5e1f8', '28', 'Zithromax 500mg', 'Azithromycin', 'BAT-787', '2027-10-28', 47, 121.80, 0, '2026-06-08 19:30:00'),
('ec1df9f1-ae0e-559e-a757-3f71aa46a697', '28', 'Flagyl 500mg', 'Metronidazole', 'BAT-787', '2027-10-28', 47, 25.20, 0, '2026-06-08 19:30:00'),
('b3c9f946-de72-5487-b065-f1ecd5fddddf', '28', 'Rocephin 1g', 'Ceftriaxone', 'BAT-787', '2027-10-28', 47, 124.95, 1, '2026-06-08 19:30:00'),
('9d08a563-30fa-5edb-a265-e98cbd6c5ee8', '28', 'Tavanic 500mg', 'Levofloxacin', 'BAT-787', '2027-10-28', 47, 122.85, 0, '2026-06-08 19:30:00'),
('bd89ce7c-9623-52ba-b9fc-4fc63c403c66', '28', 'Cravit 500mg', 'Levofloxacin', 'BAT-787', '2027-10-28', 47, 30.45, 1, '2026-06-08 19:30:00'),
('0fd95f8e-083b-5924-99c2-7f3eebc76624', '28', 'Glucophage 500mg', 'Metformin', 'BAT-787', '2027-10-28', 47, 143.85, 1, '2026-06-08 19:30:00'),
('67016598-3703-5be2-95f6-453d99a06b17', '28', 'Glucophage XR 750mg', 'Metformin Extended Release', 'BAT-787', '2027-10-28', 47, 147.00, 0, '2026-06-08 19:30:00'),
('0c110f09-52a0-589e-a8cd-e032898842f3', '28', 'Diamicron 60mg', 'Gliclazide', 'BAT-787', '2027-10-28', 47, 19.95, 1, '2026-06-08 19:30:00'),
('d77e4734-851a-5580-bf3b-21f7d359030f', '28', 'Januvia 100mg', 'Sitagliptin', 'BAT-787', '2027-10-28', 47, 147.00, 1, '2026-06-08 19:30:00'),
('18f599d8-3413-5012-8eee-3e4991f0b34d', '28', 'Antinal 400mg', 'Nifuroxazide', 'BAT-787', '2027-10-28', 47, 60.90, 1, '2026-06-08 19:30:00'),
('fb6db7c8-3c4a-52c8-a40b-1b2acad14695', '28', 'Entocid', 'Bismuth Subsalicylate', 'BAT-787', '2027-10-28', 47, 33.60, 1, '2026-06-08 19:30:00'),
('86282da1-5015-57db-a4c4-ab77d88ae406', '28', 'Spasmex 20mg', 'Mebeverine', 'BAT-787', '2027-10-28', 47, 17.85, 1, '2026-06-08 19:30:00'),
('26ff3b9a-63f8-5ab7-8019-1befd665c5d7', '28', 'Buscopan 10mg', 'Hyoscine Butylbromide', 'BAT-787', '2027-10-28', 47, 26.25, 0, '2026-06-08 19:30:00'),
('2a7af51c-8e7b-5910-bdbc-2e56836efc6d', '28', 'Miconazole Cream', 'Miconazole', 'BAT-787', '2027-10-28', 47, 140.70, 1, '2026-06-08 19:30:00'),
('8118121e-83e1-589b-8426-289fba29b9f6', '28', 'Canesten Cream', 'Clotrimazole', 'BAT-787', '2027-10-28', 47, 138.60, 1, '2026-06-08 19:30:00'),
('aeb4662e-e270-5fc7-8485-8da71c43e5c6', '28', 'Fucicort Cream', 'Fusidic Acid + Betamethasone', 'BAT-787', '2027-10-28', 47, 145.95, 1, '2026-06-08 19:30:00'),
('957f5b30-7e33-5674-a276-4deb4142d516', '28', 'Kenacort Injection', 'Triamcinolone', 'BAT-787', '2027-10-28', 47, 132.30, 1, '2026-06-08 19:30:00'),
('180a3c97-1715-5a59-b81d-d94a8e6cc494', '28', 'Depo-Medrol Injection', 'Methylprednisolone', 'BAT-787', '2027-10-28', 47, 71.40, 0, '2026-06-08 19:30:00'),
('584661fb-b57b-5efb-a3e1-f99072e70208', '28', 'Hydrocortisone Cream 1%', 'Hydrocortisone', 'BAT-787', '2027-10-28', 47, 43.05, 1, '2026-06-08 19:30:00'),
('a72b048b-1ef3-5f57-8dd1-c8d3ef37bd6d', '28', 'Ebastel 10mg', 'Ebastine', 'BAT-787', '2027-10-28', 47, 37.80, 0, '2026-06-08 19:30:00'),
('04d46ef8-e6f9-57a5-941f-5fb63e7bcc45', '28', 'Telfast 180mg', 'Fexofenadine', 'BAT-787', '2027-10-28', 47, 68.25, 1, '2026-06-08 19:30:00'),
('226dcd0b-3df9-5911-a5f3-f355497f9f7f', '28', 'Zyrtec 10mg', 'Cetirizine Hydrochloride', 'BAT-787', '2027-10-28', 47, 36.75, 1, '2026-06-08 19:30:00'),
('0cad4ef6-05f0-5af8-9821-9608ebc0bed8', '28', 'Claritin 10mg', 'Loratadine', 'BAT-787', '2027-10-28', 47, 47.25, 0, '2026-06-08 19:30:00'),
('3086d545-b145-5138-a657-1b9e547a54de', '28', 'Rhinathiol 200mg', 'Carbocisteine', 'BAT-787', '2027-10-28', 47, 85.05, 0, '2026-06-08 19:30:00'),
('7fd19bbb-b40e-58d2-bd93-cb587756b30d', '28', 'Solmucol 600mg', 'Acetylcysteine', 'BAT-787', '2027-10-28', 47, 111.30, 0, '2026-06-08 19:30:00'),
('6c89efa1-0e26-56d3-b461-8c644f80c3ef', '28', 'Bisolvon 8mg', 'Bromhexine', 'BAT-787', '2027-10-28', 47, 130.20, 1, '2026-06-08 19:30:00'),
('4a061e94-c4c2-5425-8812-e37107d923de', '28', 'Ventolin Inhaler', 'Salbutamol', 'BAT-787', '2027-10-28', 47, 47.25, 0, '2026-06-08 19:30:00'),
('896e9c00-29af-5510-a8ff-f5c4931b15ab', '28', 'Seretide Inhaler', 'Fluticasone + Salmeterol', 'BAT-787', '2027-10-28', 47, 102.90, 1, '2026-06-08 19:30:00'),
('43185dbe-bcba-557f-971c-184c67e5ff67', '28', 'Singulair 10mg', 'Montelukast', 'BAT-787', '2027-10-28', 47, 45.15, 1, '2026-06-08 19:30:00'),
('553930a8-b10c-575b-9fb3-68a8574c870e', '28', 'Avamys Nasal Spray', 'Fluticasone Furoate', 'BAT-787', '2027-10-28', 47, 36.75, 0, '2026-06-08 19:30:00'),
('1cbed5e3-1b22-5c9d-bb69-1d18d9825aaf', '28', 'Otrivin Nasal Spray', 'Xylometazoline', 'BAT-787', '2027-10-28', 47, 23.10, 1, '2026-06-08 19:30:00'),
('93f025d4-f8b3-5b8a-8a0a-0aece36cc1f3', '28', 'Conventu', 'Conventu', 'BAT-787', '2027-10-28', 47, 18.90, 1, '2026-06-08 19:30:00'),
('eaa54d95-b11e-537c-82df-09fc805b92a3', '28', 'Recoxibright', 'Etoricoxib', 'BAT-787', '2027-10-28', 47, 89.25, 0, '2026-06-08 19:30:00'),
('5dfd9d5e-dd53-5fc6-b1dd-a1a46d035e06', '28', 'Sulfox', 'Cetyl Myristoleate + Glucosamine + MSM', 'BAT-787', '2027-10-28', 47, 52.50, 1, '2026-06-08 19:30:00'),
('2995c3e0-1ac7-5a50-92ae-8e901df9edb8', '28', 'Sulfora gel', 'Cetyl Myristoleate + Glucosamine + MSM', 'BAT-787', '2027-10-28', 47, 145.95, 1, '2026-06-08 19:30:00'),
('d826331a-aafb-57b9-a2bf-b2a77d4be07e', '28', 'Random Drug 50mg', 'Random Drug 50mg', 'BAT-787', '2027-10-28', 47, 122.85, 1, '2026-06-08 19:30:00'),
('719c4835-73cc-530a-b70d-73f30ef9fa14', '28', 'Convenntu 100mg', 'Convenntu 100mg', 'BAT-787', '2027-10-28', 47, 126.00, 0, '2026-06-08 19:30:00'),
('46f11328-a488-5e5b-b7ed-b723b900ac2a', '28', 'Recoribright 90mg', 'Recoribright 90mg', 'BAT-787', '2027-10-28', 47, 54.60, 1, '2026-06-08 19:30:00'),
('242ebe24-441e-5a7f-a353-f6e2df32d329', '28', 'Sulfoa gel', 'Cetyl Myristoleate + Glucosamine + MSM', 'BAT-787', '2027-10-28', 47, 110.25, 0, '2026-06-08 19:30:00'),
('9bf9a58a-baa9-57a8-b5a0-4076c14af28b', '28', 'Sulfiox gel', 'Sulfiox gel', 'BAT-787', '2027-10-28', 47, 50.40, 0, '2026-06-08 19:30:00'),
('c3d20eac-03f6-5477-a9d1-2d46eb8f229c', '28', 'Conventus', 'Conventus', 'BAT-787', '2027-10-28', 47, 150.15, 0, '2026-06-08 19:30:00'),
('de376c79-267d-5250-a65e-101940cc410c', '28', 'Convenia 100mg', 'Convenia 100mg', 'BAT-787', '2027-10-28', 47, 122.85, 0, '2026-06-08 19:30:00'),
('3d7315bb-b7d6-5dc7-9edc-e4df79c78d45', '28', 'TestMed3', 'TestMed3', 'BAT-787', '2027-10-28', 47, 55.65, 1, '2026-06-08 19:30:00'),
('97252b89-b2e3-54e1-b0bb-46f59d40ba36', '28', 'Conventin 100mg', 'Gabapentin', 'BAT-787', '2027-10-28', 47, 73.50, 0, '2026-06-08 19:30:00'),
('2eb54237-4af7-5237-a822-cf323f9f784e', '28', 'Recoxibright 90mg', 'Etoricoxib', 'BAT-787', '2027-10-28', 47, 99.75, 1, '2026-06-08 19:30:00'),
('be29c982-4b04-5d77-9694-b354c25f5c44', '28', 'Sulfax Gel', 'Cetyl Myristoleate + Glucosamine + MSM', 'BAT-787', '2027-10-28', 47, 57.75, 1, '2026-06-08 19:30:00'),
('9c282aa3-15fb-5c02-9e41-a01b0764c1aa', '28', 'Venusen Compression Stocking (Class II, XL, Under-knee)', 'OCR Extracted', 'BAT-787', '2027-10-28', 47, 189.00, 0, '2026-06-08 19:30:00'),
('39b68c61-b22a-5f6e-8f4d-b5dfbe1f113e', '28', 'Venusen Medical Compression Stockings (Below Knee)', 'OCR Extracted', 'BAT-787', '2027-10-28', 47, 189.00, 0, '2026-06-08 19:30:00'),
('33d2efb4-2b0f-5449-b2e8-c5a614d04877', '28', 'Venusen Compression Stocking (Below Knee, Class II, XL)', 'OCR Extracted', 'BAT-787', '2027-10-28', 47, 189.00, 0, '2026-06-08 19:30:00'),
('4829b35e-4f23-5481-9195-34784452355b', '28', 'NonExistent Medicine', 'OCR Extracted', 'BAT-787', '2027-10-28', 47, 142.80, 1, '2026-06-08 19:30:00'),
('4470cb66-5000-5aa3-a319-afd7a537a091', '28', 'Venosen Compression Stockings (Below Knee, Class II, XL)', 'OCR Extracted', 'BAT-787', '2027-10-28', 47, 189.00, 0, '2026-06-08 19:30:00'),
('37aefe44-e753-5e2c-96de-e2b4ed989226', '28', 'Prescribed Items', 'OCR Extracted', 'BAT-787', '2027-10-28', 47, 71.40, 1, '2026-06-08 19:30:00'),
('e7d00b3d-5a39-5a19-9006-8b116afe7a4f', '28', 'Panadol Extra', 'Paracetamol + Caffeine', 'BAT-787', '2027-10-28', 47, 25.20, 0, '2026-06-08 19:30:00'),
('baf59932-b151-51cf-b6fd-b60993f4fae8', '28', 'Solpadeine Active', 'Paracetamol + Caffeine + Codeine', 'BAT-787', '2027-10-28', 47, 21.00, 0, '2026-06-08 19:30:00'),
('9dd9f798-cb13-5e69-9b51-2176d84cd191', '28', 'Lipitor 20mg', 'Atorvastatin Calcium', 'BAT-787', '2027-10-28', 47, 137.55, 0, '2026-06-08 19:30:00'),
('c6264931-ab7c-5ec0-927e-d60375f2d1d6', '28', 'Nexium 40mg', 'Esomeprazole', 'BAT-787', '2027-10-28', 47, 89.25, 0, '2026-06-08 19:30:00'),
('e72b90fe-45de-582d-b1b2-e7cb438d4c05', '28', 'Augmentin 1gm', 'Amoxicillin + Clavulanate Potassium', 'BAT-787', '2027-10-28', 47, 89.25, 0, '2026-06-08 19:30:00'),
('0dba1b42-510a-54a8-a317-b5e15f5be577', '28', 'Cataflam 50mg', 'Diclofenac Potassium', 'BAT-787', '2027-10-28', 47, 37.80, 0, '2026-06-08 19:30:00'),
('f72a26e8-7a3f-5c69-973e-acaf50016bec', '28', 'Flotac', 'OCR Extracted', 'BAT-787', '2027-10-28', 47, 67.20, 1, '2026-06-08 19:30:00'),
('d49244fd-69a1-576a-a44c-22607f2acc62', '28', 'Duphaston', 'OCR Extracted', 'BAT-787', '2027-10-28', 47, 126.00, 1, '2026-06-08 19:30:00'),
('63283a9b-0f88-5dc5-83d5-7d7a1617eb5c', '28', 'H Daben Capsule', 'OCR Extracted', 'BAT-787', '2027-10-28', 47, 53.55, 1, '2026-06-08 19:30:00'),
('0bf44344-1453-5fa6-ba60-e8f82e97781c', '28', 'MegaVera 120mg Test', 'OCR Extracted', 'BAT-787', '2027-10-28', 47, 27.30, 1, '2026-06-08 19:30:00'),
('f1df59b8-7d0c-55ed-a9c5-073e3b177d55', '28', 'Venesen Compression Stockings, Knee-high, Size XL, Class II', 'OCR Extracted', 'BAT-787', '2027-10-28', 47, 129.15, 0, '2026-06-08 19:30:00'),
('2f6f9eae-98f6-5faa-8504-3d66d7746a22', '28', 'E2ETestMedicine', 'E2ETestGeneric', 'BAT-787', '2027-10-28', 47, 112.35, 0, '2026-06-08 19:30:00'),
('a555824e-f796-511b-9dbe-808e8a031edf', '28', 'Cozaar 50mg', 'Losartan Potassium (Cozaar)', 'BAT-787', '2027-10-28', 47, 91.35, 1, '2026-06-08 19:30:00'),
('4db45597-bb4c-51c0-89f6-b5f831ff0913', '28', 'Pecoribright', 'OCR Extracted', 'BAT-787', '2027-10-28', 47, 44.10, 1, '2026-06-08 19:30:00'),
('ff971180-adda-5cfa-96e2-9e39b7c4306d', '28', 'Venuson Compression Stocking', 'OCR Extracted', 'BAT-787', '2027-10-28', 47, 189.00, 0, '2026-06-08 19:30:00'),
('8c0523dc-1b79-5285-8470-710e66153a3f', '28', 'Venusen Compression Stocking Class II, XL (Below Knee, Open Toe)', 'OCR Extracted', 'BAT-787', '2027-10-28', 47, 189.00, 1, '2026-06-08 19:30:00'),
('5aef85ec-2a99-5a26-a559-7d7a2f74c8a3', '28', 'Venusen Compression Stocking (Below Knee, Open Toe)', 'OCR Extracted', 'BAT-787', '2027-10-28', 47, 189.00, 1, '2026-06-08 19:30:00'),
('a14257cb-6321-5f0f-a301-78007c8cc104', '28', 'Gluonorm', 'OCR Extracted', 'BAT-787', '2027-10-28', 47, 118.65, 1, '2026-06-08 19:30:00'),
('87d97212-2013-5a22-a7ce-e3ac7c957c18', '28', 'Furamil', 'OCR Extracted', 'BAT-787', '2027-10-28', 47, 30.45, 1, '2026-06-08 19:30:00'),
('548676df-9995-584a-9f7d-e44bc963e993', '28', 'Jivomed', 'OCR Extracted', 'BAT-787', '2027-10-28', 47, 77.70, 1, '2026-06-08 19:30:00'),
('6c15476c-8dbe-5f1b-8983-dbdf38f8788c', '28', 'Thiopro', 'OCR Extracted', 'BAT-787', '2027-10-28', 47, 115.50, 0, '2026-06-08 19:30:00'),
('2afdce8f-47bc-57dd-8103-72566888388f', '28', 'Unresolved Medicine', 'OCR Extracted', 'BAT-787', '2027-10-28', 47, 35.70, 1, '2026-06-08 19:30:00'),
('9a2dab15-b916-591f-ae55-844d3f0530ba', '28', 'Conveniui', 'OCR Extracted', 'BAT-787', '2027-10-28', 47, 78.75, 1, '2026-06-08 19:30:00'),
('0e58a8d0-0c74-5440-95de-16df4eb477b7', '28', 'Puravil', 'OCR Extracted', 'BAT-787', '2027-10-28', 47, 94.50, 0, '2026-06-08 19:30:00'),
('7e4a3901-3b20-574a-8467-5aaa0e44b889', '28', 'Convenlur', 'OCR Extracted', 'BAT-787', '2027-10-28', 47, 123.90, 0, '2026-06-08 19:30:00');

--
-- Triggers `medicine_inventory`
--
DELIMITER $$
CREATE TRIGGER `expiry_alert_trigger` AFTER INSERT ON `medicine_inventory` FOR EACH ROW BEGIN
    IF NEW.expiry_date <= DATE_ADD(CURDATE(), INTERVAL 30 DAY) THEN
        INSERT INTO notifications (user_id, type, message)
        SELECT owner_id, 'expiry_alert',
               CONCAT('Expiry alert: ', NEW.medicine_name, ' expires on ', NEW.expiry_date)
        FROM pharmacies
        WHERE pharmacy_id = NEW.pharmacy_id;
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `low_stock_alert_trigger` AFTER UPDATE ON `medicine_inventory` FOR EACH ROW BEGIN
    IF NEW.stock_quantity < 10 AND OLD.stock_quantity >= 10 THEN
        INSERT INTO notifications (user_id, type, message)
        SELECT owner_id, 'stock_update', 
               CONCAT('Low stock alert: ', NEW.medicine_name, ' only ', NEW.stock_quantity, ' left')
        FROM pharmacies
        WHERE pharmacy_id = NEW.pharmacy_id;
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `medicine_recalls`
--

CREATE TABLE `medicine_recalls` (
  `recall_id` int(11) NOT NULL,
  `medicine_name` varchar(150) NOT NULL,
  `batch_number` varchar(100) DEFAULT NULL,
  `reason` text DEFAULT NULL,
  `issued_by_regulator` varchar(100) DEFAULT NULL,
  `issued_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `medicine_recalls`
--

INSERT INTO `medicine_recalls` (`recall_id`, `medicine_name`, `batch_number`, `reason`, `issued_by_regulator`, `issued_at`) VALUES
(1, 'Panadol 500mg', 'PAN2023999', 'Packaging error', 'FDA', '2026-04-20 14:01:57'),
(2, 'Panadol 500mg', 'PAN2023999', 'Packaging error', 'FDA', '2026-04-20 14:02:21');

-- --------------------------------------------------------

--
-- Stand-in structure for view `nearby_pharmacies_with_stock`
-- (See below for the actual view)
--
CREATE TABLE `nearby_pharmacies_with_stock` (
`pharmacy_id` char(36)
,`name` varchar(150)
,`address` text
,`rating` decimal(3,2)
,`delivery_available` tinyint(1)
,`medicine_name` varchar(150)
,`stock_quantity` int(11)
,`price` decimal(10,2)
,`expiry_date` date
);

-- --------------------------------------------------------

--
-- Table structure for table `notifications`
--

CREATE TABLE `notifications` (
  `notification_id` char(36) NOT NULL DEFAULT uuid(),
  `user_id` char(36) NOT NULL,
  `type` enum('stock_update','reservation','expiry_alert','recall','alternative_available','promotion') NOT NULL,
  `message` text NOT NULL,
  `is_read` tinyint(1) DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `notifications`
--

INSERT INTO `notifications` (`notification_id`, `user_id`, `type`, `message`, `is_read`, `created_at`) VALUES
('20fc502c-3ccb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Paracetamol 500mg expires on 2025-12-31', 0, '2026-04-20 15:10:55'),
('20fc748c-3ccb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Ibuprofen 400mg expires on 2025-11-30', 0, '2026-04-20 15:10:55'),
('20fc75d8-3ccb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Amoxicillin 500mg expires on 2025-10-15', 0, '2026-04-20 15:10:55'),
('20fc76dd-3ccb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Azithromycin 500mg expires on 2025-09-20', 0, '2026-04-20 15:10:55'),
('20fc77ad-3ccb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Cetirizine 10mg expires on 2026-01-15', 0, '2026-04-20 15:10:55'),
('20ff8ff7-3ccb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Paracetamol 500mg expires on 2025-12-31', 0, '2026-04-20 15:10:55'),
('20ff91ec-3ccb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Metformin 500mg expires on 2025-08-30', 0, '2026-04-20 15:10:55'),
('20ff92f9-3ccb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Lisinopril 10mg expires on 2025-10-10', 0, '2026-04-20 15:10:55'),
('20ff9466-3ccb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Albuterol Inhaler expires on 2025-07-15', 0, '2026-04-20 15:10:55'),
('20ff954f-3ccb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Omeprazole 20mg expires on 2026-02-28', 0, '2026-04-20 15:10:55'),
('2102f7b5-3ccb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Amoxicillin 500mg expires on 2025-11-20', 0, '2026-04-20 15:10:55'),
('2102fb37-3ccb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Ciprofloxacin 500mg expires on 2025-09-25', 0, '2026-04-20 15:10:55'),
('2102fcff-3ccb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Doxycycline 100mg expires on 2025-12-05', 0, '2026-04-20 15:10:55'),
('2102ff86-3ccb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Loratadine 10mg expires on 2026-01-10', 0, '2026-04-20 15:10:55'),
('508f174d-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Panadol Extra 500mg expires on 2025-12-31', 0, '2026-04-20 17:06:46'),
('508f35f0-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Mortal 400mg expires on 2025-11-15', 0, '2026-04-20 17:06:46'),
('508f3909-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Amoxil 500mg expires on 2025-10-20', 0, '2026-04-20 17:06:46'),
('508f3b1a-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Antinal 400mg expires on 2025-12-10', 0, '2026-04-20 17:06:46'),
('5093b005-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Panadol Extra 500mg expires on 2026-01-31', 0, '2026-04-20 17:06:46'),
('5093b4bb-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Augmentin 1g expires on 2025-09-30', 0, '2026-04-20 17:06:46'),
('50942fac-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Flagyl 500mg expires on 2025-12-05', 0, '2026-04-20 17:06:46'),
('509432ec-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Ventolin Inhaler expires on 2025-08-15', 0, '2026-04-20 17:06:46'),
('5094351b-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Zyrtec 10mg expires on 2026-02-28', 0, '2026-04-20 17:06:46'),
('5096568d-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Catafast 50mg expires on 2025-12-15', 0, '2026-04-20 17:06:46'),
('50965962-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Zithromax 500mg expires on 2025-11-10', 0, '2026-04-20 17:06:46'),
('50965aa0-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Glucophage 500mg expires on 2026-01-20', 0, '2026-04-20 17:06:46'),
('50965bac-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Telfast 180mg expires on 2025-12-28', 0, '2026-04-20 17:06:46'),
('50965cb3-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Buscopan 10mg expires on 2026-03-15', 0, '2026-04-20 17:06:46'),
('50987253-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Panadol Cold & Flu expires on 2025-12-20', 0, '2026-04-20 17:06:46'),
('50987437-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Voltaren 75mg expires on 2026-01-05', 0, '2026-04-20 17:06:46'),
('50987530-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Brufen 600mg expires on 2025-11-25', 0, '2026-04-20 17:06:46'),
('5098761b-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Spasmex 20mg expires on 2025-12-18', 0, '2026-04-20 17:06:46'),
('509c1daf-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Ciprinol 500mg expires on 2025-10-12', 0, '2026-04-20 17:06:46'),
('509c2159-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Diamicron 60mg expires on 2026-02-01', 0, '2026-04-20 17:06:46'),
('509c23ab-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Ebastel 10mg expires on 2025-12-08', 0, '2026-04-20 17:06:46'),
('509c259b-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Solmucol 600mg expires on 2025-11-28', 0, '2026-04-20 17:06:46'),
('509e1d28-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Tavanic 500mg expires on 2025-09-20', 0, '2026-04-20 17:06:46'),
('509e20b6-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Cravit 500mg expires on 2025-10-05', 0, '2026-04-20 17:06:46'),
('509e2289-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Januvia 100mg expires on 2026-01-15', 0, '2026-04-20 17:06:46'),
('509e2439-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Claritin 10mg expires on 2026-03-01', 0, '2026-04-20 17:06:46'),
('50a082fa-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Glucophage XR 750mg expires on 2026-02-10', 0, '2026-04-20 17:06:46'),
('50a086e6-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Singulair 10mg expires on 2025-12-22', 0, '2026-04-20 17:06:46'),
('50a08930-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Seretide Inhaler expires on 2025-09-18', 0, '2026-04-20 17:06:46'),
('50a08b29-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Avamys Nasal Spray expires on 2026-01-25', 0, '2026-04-20 17:06:46'),
('50a266a0-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Rocephin 1g expires on 2025-11-15', 0, '2026-04-20 17:06:46'),
('50a26ed9-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Entocid expires on 2026-01-10', 0, '2026-04-20 17:06:46'),
('50a272a2-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Rhinathiol 200mg expires on 2025-12-05', 0, '2026-04-20 17:06:46'),
('50a273d0-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Bisolvon 8mg expires on 2026-02-20', 0, '2026-04-20 17:06:46'),
('50a4509a-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Panadol Extra 500mg expires on 2026-01-31', 0, '2026-04-20 17:06:47'),
('50a4524a-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Amoxil 500mg expires on 2025-11-20', 0, '2026-04-20 17:06:47'),
('50a45324-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Mortal 400mg expires on 2025-12-15', 0, '2026-04-20 17:06:47'),
('50a453e3-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Flagyl 500mg expires on 2025-12-20', 0, '2026-04-20 17:06:47'),
('50a61d36-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Catafast 50mg expires on 2026-01-10', 0, '2026-04-20 17:06:47'),
('50a61ee3-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Zithromax 500mg expires on 2025-10-25', 0, '2026-04-20 17:06:47'),
('50a61fbc-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Ventolin Inhaler expires on 2025-09-05', 0, '2026-04-20 17:06:47'),
('50a6207c-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Zyrtec 10mg expires on 2026-02-28', 0, '2026-04-20 17:06:47'),
('50a8d2af-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Panadol Cold & Flu expires on 2025-12-25', 0, '2026-04-20 17:06:47'),
('50a8d4ad-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Antinal 400mg expires on 2026-01-05', 0, '2026-04-20 17:06:47'),
('50a8d597-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Spasmex 20mg expires on 2025-12-28', 0, '2026-04-20 17:06:47'),
('50a8d66d-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Buscopan 10mg expires on 2026-03-20', 0, '2026-04-20 17:06:47'),
('50ac1c16-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Voltaren 75mg expires on 2026-01-15', 0, '2026-04-20 17:06:47'),
('50ac2005-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Ciprinol 500mg expires on 2025-10-18', 0, '2026-04-20 17:06:47'),
('50ac2237-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Telfast 180mg expires on 2025-12-30', 0, '2026-04-20 17:06:47'),
('50ac24b2-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Solmucol 600mg expires on 2025-11-20', 0, '2026-04-20 17:06:47'),
('50ae0b09-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Augmentin 1g expires on 2025-10-10', 0, '2026-04-20 17:06:47'),
('50ae0dae-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Glucophage 500mg expires on 2026-02-01', 0, '2026-04-20 17:06:47'),
('50ae0f1f-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Diamicron 60mg expires on 2026-02-15', 0, '2026-04-20 17:06:47'),
('50ae105b-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Claritin 10mg expires on 2026-03-10', 0, '2026-04-20 17:06:47'),
('50b0c3a0-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Panadol Extra 500mg expires on 2026-01-31', 0, '2026-04-20 17:06:47'),
('50b0c562-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Singulair 10mg expires on 2025-12-25', 0, '2026-04-20 17:06:47'),
('50b0c640-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Seretide Inhaler expires on 2025-09-22', 0, '2026-04-20 17:06:47'),
('50b0c6fc-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Avamys Nasal Spray expires on 2026-01-30', 0, '2026-04-20 17:06:47'),
('50b0c7b0-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Ebastel 10mg expires on 2025-12-18', 0, '2026-04-20 17:06:47'),
('50b2bf44-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Brufen 600mg expires on 2025-12-05', 0, '2026-04-20 17:06:47'),
('50b2c18f-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Januvia 100mg expires on 2026-01-20', 0, '2026-04-20 17:06:47'),
('50b2c2a7-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Entocid expires on 2026-01-15', 0, '2026-04-20 17:06:47'),
('50b2c388-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Rhinathiol 200mg expires on 2025-12-10', 0, '2026-04-20 17:06:47'),
('50b4b990-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Tavanic 500mg expires on 2025-09-25', 0, '2026-04-20 17:06:47'),
('50b4bd85-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Cravit 500mg expires on 2025-10-08', 0, '2026-04-20 17:06:47'),
('50b4bf1b-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Glucophage XR 750mg expires on 2026-02-15', 0, '2026-04-20 17:06:47'),
('50b4c00b-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Bisolvon 8mg expires on 2026-02-28', 0, '2026-04-20 17:06:47'),
('50b697be-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Flagyl 500mg expires on 2025-12-25', 0, '2026-04-20 17:06:47'),
('50b6999b-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Amoxil 500mg expires on 2025-11-15', 0, '2026-04-20 17:06:47'),
('50b69a8c-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Panadol Extra 500mg expires on 2025-12-31', 0, '2026-04-20 17:06:47'),
('50b69b58-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Zyrtec 10mg expires on 2026-02-20', 0, '2026-04-20 17:06:47'),
('50b8a860-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Zithromax 500mg expires on 2025-11-05', 0, '2026-04-20 17:06:47'),
('50b8ac16-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Catafast 50mg expires on 2026-01-20', 0, '2026-04-20 17:06:47'),
('50b8cf48-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Mortal 400mg expires on 2025-12-20', 0, '2026-04-20 17:06:47'),
('50b8d1c0-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Ventolin Inhaler expires on 2025-09-10', 0, '2026-04-20 17:06:47'),
('50bab1dc-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Augmentin 1g expires on 2025-10-15', 0, '2026-04-20 17:06:47'),
('50baca95-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Glucophage 500mg expires on 2026-02-05', 0, '2026-04-20 17:06:47'),
('50bacca6-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Spasmex 20mg expires on 2026-01-10', 0, '2026-04-20 17:06:47'),
('50bace0c-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Telfast 180mg expires on 2025-12-28', 0, '2026-04-20 17:06:47'),
('50bc9b86-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Panadol Extra 500mg expires on 2026-01-31', 0, '2026-04-20 17:06:47'),
('50bc9d57-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Singulair 10mg expires on 2026-01-15', 0, '2026-04-20 17:06:47'),
('50bc9e3b-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Seretide Inhaler expires on 2025-09-28', 0, '2026-04-20 17:06:47'),
('50bc9ef0-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Antinal 400mg expires on 2026-01-08', 0, '2026-04-20 17:06:47'),
('50bc9fa8-3cdb-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Buscopan 10mg expires on 2026-03-25', 0, '2026-04-20 17:06:47'),
('7e74936a-3cc1-11f1-b1ec-70089427b150', '1', 'reservation', 'Your Panadol reservation has been confirmed at Wellness Pharmacy', 0, '2026-04-20 14:01:57'),
('7e749792-3cc1-11f1-b1ec-70089427b150', '1', 'expiry_alert', 'Your Brufen medication will expire in 30 days', 0, '2026-04-20 14:01:57'),
('8d08b5ea-3cc1-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Panadol 500mg expires on 2025-12-31', 0, '2026-04-20 14:02:21'),
('8d08bc79-3cc1-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Amoxicillin 500mg expires on 2025-10-15', 0, '2026-04-20 14:02:21'),
('8d08bfaa-3cc1-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Brufen 400mg expires on 2025-11-20', 0, '2026-04-20 14:02:21'),
('8d08c221-3cc1-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Panadol 500mg expires on 2025-12-31', 0, '2026-04-20 14:02:21'),
('8d0951b7-3cc1-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Zinacef 500mg expires on 2025-09-30', 0, '2026-04-20 14:02:21'),
('8d0953d3-3cc1-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Ventolin Inhaler expires on 2025-08-15', 0, '2026-04-20 14:02:21'),
('8d09556d-3cc1-11f1-b1ec-70089427b150', '2', 'expiry_alert', 'Expiry alert: Panadol 500mg expires on 2025-11-30', 0, '2026-04-20 14:02:21'),
('8d0db6b0-3cc1-11f1-b1ec-70089427b150', '1', 'reservation', 'Your Panadol reservation has been confirmed at Wellness Pharmacy', 0, '2026-04-20 14:02:21'),
('8d0e2c87-3cc1-11f1-b1ec-70089427b150', '1', 'expiry_alert', 'Your Brufen medication will expire in 30 days', 0, '2026-04-20 14:02:21');

-- --------------------------------------------------------

--
-- Table structure for table `pharmacies`
--

CREATE TABLE `pharmacies` (
  `pharmacy_id` char(36) NOT NULL DEFAULT uuid(),
  `name` varchar(150) NOT NULL,
  `address` text NOT NULL,
  `latitude` decimal(10,8) DEFAULT NULL,
  `longitude` decimal(11,8) DEFAULT NULL,
  `phone` varchar(20) DEFAULT NULL,
  `opening_time` time DEFAULT NULL,
  `closing_time` time DEFAULT NULL,
  `is_24_hours` tinyint(1) DEFAULT 0,
  `delivery_available` tinyint(1) DEFAULT 0,
  `rating` decimal(3,2) DEFAULT 0.00,
  `owner_id` char(36) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `pharmacies`
--

INSERT INTO `pharmacies` (`pharmacy_id`, `name`, `address`, `latitude`, `longitude`, `phone`, `opening_time`, `closing_time`, `is_24_hours`, `delivery_available`, `rating`, `owner_id`) VALUES
('1', 'Sief Pharmacy', '123 Main Street, Cairo, Egypt', 30.04440000, 31.23570000, '+20 10 60981547', '09:00:00', '23:00:00', 0, 1, 4.50, '2'),
('2', '24x7 Medico', '456 Nile Street, Cairo, Egypt', 30.04420000, 31.23550000, '+20 10 12345679', '00:00:00', '23:59:59', 0, 1, 4.80, '2'),
('3', 'Health Plus Pharmacy', '789 Pyramids Road, Giza, Egypt', 29.98700000, 31.21180000, '+20 10 43789676', '09:00:00', '23:00:00', 0, 0, 4.20, '2'),
('4', 'Seif Pharmacy', '15 Tahrir Street, Downtown, Cairo, Egypt', 30.04440000, 31.23570000, '+20 10 26795428', '09:00:00', '23:00:00', 0, 1, 4.50, '2'),
('5', 'Ezaby Pharmacy - Ramses', '2 Ramses Street, Ramses Square, Cairo, Egypt', 30.05660000, 31.23340000, '+20 10 56319298', '09:00:00', '23:00:00', 1, 1, 4.80, '2'),
('6', 'El Ezaby Pharmacy - Nasr City', '90 Abbas El Akkad Street, Nasr City, Cairo, Egypt', 30.06240000, 31.33260000, '+20 10 15349216', '09:00:00', '23:00:00', 0, 1, 4.60, '2'),
('7', 'Nile Pharmacy', '35 Kasr El Nile Street, Downtown, Cairo, Egypt', 30.04550000, 31.23660000, '+20 10 14637501', '09:00:00', '23:00:00', 0, 1, 4.40, '2'),
('8', 'Cairo Pharmacy', '12 Adly Street, Downtown, Cairo, Egypt', 30.04660000, 31.23770000, '+20 10 35407378', '09:00:00', '23:00:00', 0, 1, 4.30, '2'),
('9', 'Garden City Pharmacy', '5 Garden City Street, Garden City, Cairo, Egypt', 30.04000000, 31.22800000, '+20 10 85789908', '09:00:00', '23:00:00', 0, 0, 4.20, '2'),
('10', 'Zamalek Pharmacy', '26 July Street, Zamalek, Cairo, Egypt', 30.06440000, 31.21670000, '+20 10 86018760', '09:00:00', '23:00:00', 0, 1, 4.70, '2'),
('11', 'Maadi Pharmacy', '9 Road 9, Maadi, Cairo, Egypt', 29.96670000, 31.25000000, '+20 10 36905090', '09:00:00', '23:00:00', 0, 1, 4.50, '2'),
('12', 'Heliopolis Pharmacy', '40 El Horreya Street, Heliopolis, Cairo, Egypt', 30.09000000, 31.33000000, '+20 10 71854246', '09:00:00', '23:00:00', 0, 1, 4.40, '2'),
('13', 'El Mohandeseen Pharmacy', '15 Syria Street, Mohandeseen, Giza (Greater Cairo), Egypt', 30.04800000, 31.20300000, '+20 10 78082363', '09:00:00', '23:00:00', 0, 1, 4.60, '2'),
('14', 'Shobra Pharmacy', '20 Shobra Street, Shobra, Cairo, Egypt', 30.07500000, 31.24000000, '+20 10 81638559', '09:00:00', '23:00:00', 0, 1, 4.10, '2'),
('15', 'Abbassiya Pharmacy', '10 Abbassiya Square, Abbassiya, Cairo, Egypt', 30.06300000, 31.26800000, '+20 10 29757055', '09:00:00', '23:00:00', 0, 0, 4.00, '2'),
('16', 'El Nozha Pharmacy', '5 Nozha Street, Heliopolis, Cairo, Egypt', 30.09500000, 31.34000000, '+20 10 18759766', '09:00:00', '23:00:00', 0, 1, 4.30, '2'),
('17', 'City Stars Pharmacy', 'City Stars Mall, Omar Ibn El Khattab St, Heliopolis, Cairo, Egypt', 30.10200000, 31.34500000, '+20 10 99104579', '09:00:00', '23:00:00', 0, 1, 4.80, '2'),
('18', 'Dokki Pharmacy', '25 Mosadek Street, Dokki, Giza (Greater Cairo), Egypt', 30.03700000, 31.21200000, '+20 10 37207081', '09:00:00', '23:00:00', 0, 1, 4.20, '2'),
('19', 'Hadayek El Kobba Pharmacy', '8 Hadayek El Kobba Street, Cairo, Egypt', 30.08200000, 31.29000000, '+20 10 66121207', '09:00:00', '23:00:00', 0, 1, 4.40, '2'),
('20', 'El Demerdash Pharmacy', '15 El Demerdash Street, Cairo, Egypt', 30.05800000, 31.27000000, '+20 10 55342620', '09:00:00', '23:00:00', 0, 0, 4.10, '2'),
('21', 'New Cairo Pharmacy', '55 El Tesseen Street, New Cairo, Cairo, Egypt', 30.00800000, 31.44100000, '+20 10 51956518', '09:00:00', '23:00:00', 0, 1, 4.70, '2'),
('22', 'Rehab Pharmacy', 'Gate 5, Rehab City, New Cairo, Cairo, Egypt', 30.01500000, 31.46000000, '+20 10 76045636', '09:00:00', '23:00:00', 0, 1, 4.50, '2'),
('23', 'Fifth Settlement Pharmacy', '90 South Tesseen, Fifth Settlement, New Cairo, Cairo, Egypt', 30.02000000, 31.45000000, '+20 10 16816513', '09:00:00', '23:00:00', 0, 1, 4.60, '2'),
('24', 'Ain Helwan Pharmacy', 'Ain Helwan Square, Helwan, Cairo, Egypt', 29.85920000, 31.32110000, '+20 10 9876 5432', '08:00:00', '23:00:00', 0, 1, 4.50, NULL),
('25', 'Hadayek Helwan Pharmacy', 'El-Shaheed Street, Hadayek Helwan, Cairo, Egypt', 29.89810000, 31.30250000, '+20 10 9876 5433', '09:00:00', '23:00:00', 0, 1, 4.40, NULL),
('26', 'Helwan Square Pharmacy', 'Helwan Square, Helwan, Cairo, Egypt', 29.84150000, 31.32880000, '+20 10 9876 5434', '00:00:00', '23:59:59', 1, 1, 4.70, NULL),
('27', 'Arab Rashed Pharmacy', 'Arab Rashed Street, Helwan, Cairo, Egypt', 29.84550000, 31.31220000, '+20 10 9876 5435', '08:00:00', '22:00:00', 0, 0, 4.10, NULL),
('28', '15th of May City Pharmacy', 'District 3, 15th of May City, Cairo, Egypt', 29.89220000, 31.37880000, '+20 10 9876 5436', '09:00:00', '22:00:00', 0, 1, 4.30, NULL);

-- --------------------------------------------------------

--
-- Table structure for table `prescriptions`
--

CREATE TABLE `prescriptions` (
  `prescription_id` char(36) NOT NULL DEFAULT uuid(),
  `user_id` char(36) NOT NULL,
  `family_member_id` char(36) DEFAULT NULL,
  `image_url` varchar(500) DEFAULT NULL,
  `extracted_text` text DEFAULT NULL,
  `status` enum('uploaded','processed','reserved','filled','delivered','expired') DEFAULT 'uploaded',
  `uploaded_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `prescriptions`
--

INSERT INTO `prescriptions` (`prescription_id`, `user_id`, `family_member_id`, `image_url`, `extracted_text`, `status`, `uploaded_at`) VALUES
('0290a130-fe37-48bc-aeec-b9cdb0c5cd86', '6a772683-4a38-11f1-a285-38a74637b0e8', NULL, '/uploads/prescription_6a772683-4a38-11f1-a285-38a74637b0e8_17923cf4.jpg', 'Simulated OCR Text: Paracetamol 500mg, Amoxicillin 500mg', 'uploaded', '2026-05-07 18:48:04'),
('1c7d2dc0-060c-447e-b1df-e112f87ad39d', '6a772683-4a38-11f1-a285-38a74637b0e8', NULL, '/uploads/prescription_6a772683-4a38-11f1-a285-38a74637b0e8_f5b54c78.jpg', 'Simulated OCR Text: Paracetamol 500mg, Amoxicillin 500mg', 'uploaded', '2026-05-07 17:38:54'),
('5fe09829-87b1-470d-8905-39b0e626a9ee', '6a772683-4a38-11f1-a285-38a74637b0e8', NULL, '/uploads/prescription_6a772683-4a38-11f1-a285-38a74637b0e8_aff320a8.jpg', 'Simulated OCR Text: Paracetamol 500mg, Amoxicillin 500mg', 'uploaded', '2026-05-07 17:57:06'),
('94bd5cd5-e721-40e3-ad9b-297479d2fb7a', '6a772683-4a38-11f1-a285-38a74637b0e8', NULL, '/uploads/prescription_6a772683-4a38-11f1-a285-38a74637b0e8_1bf937b8.jpg', 'Simulated OCR Text: Paracetamol 500mg, Amoxicillin 500mg', 'uploaded', '2026-05-07 18:30:38'),
('b55a1d9d-12e9-4621-bd2a-61af3c33d66d', '2e659bbb-4a3d-11f1-a285-38a74637b0e8', NULL, '/uploads/prescription_2e659bbb-4a3d-11f1-a285-38a74637b0e8_4e65d2f8.jpg', 'Simulated OCR Text: Paracetamol 500mg, Amoxicillin 500mg', 'uploaded', '2026-05-07 18:41:03');

-- --------------------------------------------------------

--
-- Table structure for table `prescription_medicines`
--

CREATE TABLE `prescription_medicines` (
  `id` char(36) NOT NULL DEFAULT uuid(),
  `prescription_id` char(36) NOT NULL,
  `medicine_name` varchar(150) NOT NULL,
  `dosage` varchar(100) DEFAULT NULL,
  `frequency` varchar(100) DEFAULT NULL,
  `duration_days` int(11) DEFAULT NULL,
  `quantity` int(11) DEFAULT NULL,
  `alternative_approved` tinyint(1) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `prescription_medicines`
--

INSERT INTO `prescription_medicines` (`id`, `prescription_id`, `medicine_name`, `dosage`, `frequency`, `duration_days`, `quantity`, `alternative_approved`) VALUES
('49aa99fc-01cd-4e51-9df6-4e18e72253da', '94bd5cd5-e721-40e3-ad9b-297479d2fb7a', 'Amoxicillin 500mg', NULL, NULL, NULL, NULL, 0),
('4f88e630-168f-40e6-9465-2a4a8493e30f', '94bd5cd5-e721-40e3-ad9b-297479d2fb7a', 'Paracetamol 500mg', NULL, NULL, NULL, NULL, 0),
('95b5e9e9-7b31-439e-a3d9-afac1280a2f4', '1c7d2dc0-060c-447e-b1df-e112f87ad39d', 'Paracetamol 500mg', NULL, NULL, NULL, NULL, 0),
('95f4a3c5-6e1c-41d4-9c10-6e0a1df989f1', '0290a130-fe37-48bc-aeec-b9cdb0c5cd86', 'Amoxicillin 500mg', NULL, NULL, NULL, NULL, 0),
('97f26b78-7bd1-4bb3-af92-801c3f862cc2', 'b55a1d9d-12e9-4621-bd2a-61af3c33d66d', 'Paracetamol 500mg', NULL, NULL, NULL, NULL, 0),
('99390464-1aef-41aa-b080-669815fad2eb', '0290a130-fe37-48bc-aeec-b9cdb0c5cd86', 'Paracetamol 500mg', NULL, NULL, NULL, NULL, 0),
('9cfd56ef-e32c-4cf9-bd9d-4c7bbd846b75', '1c7d2dc0-060c-447e-b1df-e112f87ad39d', 'Amoxicillin 500mg', NULL, NULL, NULL, NULL, 0),
('acb39c50-0f9b-4b5b-9458-62af7bef1eb9', '5fe09829-87b1-470d-8905-39b0e626a9ee', 'Amoxicillin 500mg', NULL, NULL, NULL, NULL, 0),
('b3387c9f-542b-4e0c-9ed9-aadfce216c81', 'b55a1d9d-12e9-4621-bd2a-61af3c33d66d', 'Amoxicillin 500mg', NULL, NULL, NULL, NULL, 0),
('b7d952ad-7f69-4369-b4a9-ac103ece2705', '5fe09829-87b1-470d-8905-39b0e626a9ee', 'Paracetamol 500mg', NULL, NULL, NULL, NULL, 0);

-- --------------------------------------------------------

--
-- Table structure for table `reservations`
--

CREATE TABLE `reservations` (
  `reservation_id` char(36) NOT NULL DEFAULT uuid(),
  `user_id` char(36) NOT NULL,
  `pharmacy_id` char(36) NOT NULL,
  `prescription_medicine_id` char(36) NOT NULL,
  `status` enum('pending','confirmed','picked_up','cancelled') DEFAULT 'pending',
  `reserved_until` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `user_id` char(36) NOT NULL DEFAULT uuid(),
  `email` varchar(100) NOT NULL,
  `phone` varchar(20) NOT NULL,
  `password_hash` varchar(255) NOT NULL,
  `full_name` varchar(100) NOT NULL,
  `date_of_birth` date DEFAULT NULL,
  `gender` enum('Male','Female','Other') DEFAULT 'Other',
  `role` enum('patient','pharmacist','pharmacy_owner','delivery','doctor','admin','family_member','regulator') DEFAULT 'patient',
  `is_verified` tinyint(1) DEFAULT 0,
  `otp_secret` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`user_id`, `email`, `phone`, `password_hash`, `full_name`, `date_of_birth`, `gender`, `role`, `is_verified`, `otp_secret`) VALUES
('1', 'lobna@gmail.com', '123456789', '123456789', 'lobna mohamed', NULL, 'Female', 'patient', 1, NULL),
('2', 'sarah.pharmacy@example.com', '1234567891', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Sarah Smith', NULL, 'Other', 'pharmacy_owner', 1, NULL),
('2e659bbb-4a3d-11f1-a285-38a74637b0e8', 'test', '123', '$2b$12$6cp9LpDZ.q6wbpCzaUAfYemCdPS1hdQ3LQPvGCpOrbiMnPrF6q/1K', 'test', NULL, 'Other', 'patient', 0, NULL),
('4', 'delivery.mike@example.com', '1234567893', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Mike Wilson', NULL, 'Other', 'delivery', 1, NULL),
('5', 'admin@mediscan.com', '1234567894', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Admin System', NULL, 'Other', 'admin', 1, NULL),
('6a772683-4a38-11f1-a285-38a74637b0e8', 'loly@gmail.com', '01123650426', '$2b$12$pcdFgtKz90sjI4PqvTxHy.TGkcYFDtdMV6c13l6/lZ6UquPkY3DT.', 'loly', NULL, 'Other', 'patient', 0, NULL);

-- --------------------------------------------------------

--
-- Structure for view `low_stock_alert_view`
--
DROP TABLE IF EXISTS `low_stock_alert_view`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `low_stock_alert_view`  AS SELECT `p`.`name` AS `pharmacy_name`, `mi`.`medicine_name` AS `medicine_name`, `mi`.`stock_quantity` AS `stock_quantity`, `mi`.`expiry_date` AS `expiry_date` FROM (`medicine_inventory` `mi` join `pharmacies` `p` on(`mi`.`pharmacy_id` = `p`.`pharmacy_id`)) WHERE `mi`.`stock_quantity` < 20 AND `mi`.`expiry_date` > curdate() ORDER BY `mi`.`stock_quantity` ASC ;

-- --------------------------------------------------------

--
-- Structure for view `nearby_pharmacies_with_stock`
--
DROP TABLE IF EXISTS `nearby_pharmacies_with_stock`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `nearby_pharmacies_with_stock`  AS SELECT `p`.`pharmacy_id` AS `pharmacy_id`, `p`.`name` AS `name`, `p`.`address` AS `address`, `p`.`rating` AS `rating`, `p`.`delivery_available` AS `delivery_available`, `mi`.`medicine_name` AS `medicine_name`, `mi`.`stock_quantity` AS `stock_quantity`, `mi`.`price` AS `price`, `mi`.`expiry_date` AS `expiry_date` FROM (`pharmacies` `p` join `medicine_inventory` `mi` on(`p`.`pharmacy_id` = `mi`.`pharmacy_id`)) WHERE `mi`.`stock_quantity` > 0 AND `mi`.`expiry_date` > curdate() ;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `delivery_orders`
--
ALTER TABLE `delivery_orders`
  ADD PRIMARY KEY (`order_id`),
  ADD KEY `user_id` (`user_id`),
  ADD KEY `pharmacy_id` (`pharmacy_id`),
  ADD KEY `delivery_person_id` (`delivery_person_id`),
  ADD KEY `idx_orders_status` (`status`);

--
-- Indexes for table `family_profiles`
--
ALTER TABLE `family_profiles`
  ADD PRIMARY KEY (`family_id`),
  ADD KEY `idx_parent` (`parent_user_id`);

--
-- Indexes for table `medicine_alternatives`
--
ALTER TABLE `medicine_alternatives`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_medicine` (`medicine_name`);

--
-- Indexes for table `medicine_info`
--
ALTER TABLE `medicine_info`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `medicine_name` (`medicine_name`);

--
-- Indexes for table `medicine_inventory`
--
ALTER TABLE `medicine_inventory`
  ADD PRIMARY KEY (`inventory_id`),
  ADD KEY `idx_pharmacy_medicine` (`pharmacy_id`,`medicine_name`),
  ADD KEY `idx_expiry` (`expiry_date`),
  ADD KEY `idx_inventory_pharmacy` (`pharmacy_id`,`medicine_name`),
  ADD KEY `idx_inventory_expiry` (`expiry_date`);

--
-- Indexes for table `medicine_recalls`
--
ALTER TABLE `medicine_recalls`
  ADD PRIMARY KEY (`recall_id`);

--
-- Indexes for table `notifications`
--
ALTER TABLE `notifications`
  ADD PRIMARY KEY (`notification_id`),
  ADD KEY `idx_user_read` (`user_id`,`is_read`),
  ADD KEY `idx_notifications_user_read` (`user_id`,`is_read`);

--
-- Indexes for table `pharmacies`
--
ALTER TABLE `pharmacies`
  ADD PRIMARY KEY (`pharmacy_id`),
  ADD KEY `owner_id` (`owner_id`),
  ADD KEY `idx_location` (`latitude`,`longitude`),
  ADD KEY `idx_pharmacies_location` (`latitude`,`longitude`);

--
-- Indexes for table `prescriptions`
--
ALTER TABLE `prescriptions`
  ADD PRIMARY KEY (`prescription_id`),
  ADD KEY `family_member_id` (`family_member_id`),
  ADD KEY `idx_user` (`user_id`),
  ADD KEY `idx_status` (`status`),
  ADD KEY `idx_prescriptions_user_status` (`user_id`,`status`);

--
-- Indexes for table `prescription_medicines`
--
ALTER TABLE `prescription_medicines`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_prescription` (`prescription_id`),
  ADD KEY `idx_medicine` (`medicine_name`);

--
-- Indexes for table `reservations`
--
ALTER TABLE `reservations`
  ADD PRIMARY KEY (`reservation_id`),
  ADD KEY `pharmacy_id` (`pharmacy_id`),
  ADD KEY `prescription_medicine_id` (`prescription_medicine_id`),
  ADD KEY `idx_user_pharmacy` (`user_id`,`pharmacy_id`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`user_id`),
  ADD UNIQUE KEY `email` (`email`),
  ADD UNIQUE KEY `phone` (`phone`),
  ADD KEY `idx_email` (`email`),
  ADD KEY `idx_role` (`role`),
  ADD KEY `idx_users_email` (`email`),
  ADD KEY `idx_users_role` (`role`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `medicine_info`
--
ALTER TABLE `medicine_info`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=89;

--
-- AUTO_INCREMENT for table `medicine_recalls`
--
ALTER TABLE `medicine_recalls`
  MODIFY `recall_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `delivery_orders`
--
ALTER TABLE `delivery_orders`
  ADD CONSTRAINT `delivery_orders_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`),
  ADD CONSTRAINT `delivery_orders_ibfk_2` FOREIGN KEY (`pharmacy_id`) REFERENCES `pharmacies` (`pharmacy_id`),
  ADD CONSTRAINT `delivery_orders_ibfk_3` FOREIGN KEY (`delivery_person_id`) REFERENCES `users` (`user_id`);

--
-- Constraints for table `family_profiles`
--
ALTER TABLE `family_profiles`
  ADD CONSTRAINT `family_profiles_ibfk_1` FOREIGN KEY (`parent_user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE;

--
-- Constraints for table `medicine_inventory`
--
ALTER TABLE `medicine_inventory`
  ADD CONSTRAINT `medicine_inventory_ibfk_1` FOREIGN KEY (`pharmacy_id`) REFERENCES `pharmacies` (`pharmacy_id`) ON DELETE CASCADE;

--
-- Constraints for table `notifications`
--
ALTER TABLE `notifications`
  ADD CONSTRAINT `notifications_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE;

--
-- Constraints for table `pharmacies`
--
ALTER TABLE `pharmacies`
  ADD CONSTRAINT `pharmacies_ibfk_1` FOREIGN KEY (`owner_id`) REFERENCES `users` (`user_id`) ON DELETE SET NULL;

--
-- Constraints for table `prescriptions`
--
ALTER TABLE `prescriptions`
  ADD CONSTRAINT `prescriptions_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE,
  ADD CONSTRAINT `prescriptions_ibfk_2` FOREIGN KEY (`family_member_id`) REFERENCES `family_profiles` (`family_id`) ON DELETE SET NULL;

--
-- Constraints for table `prescription_medicines`
--
ALTER TABLE `prescription_medicines`
  ADD CONSTRAINT `prescription_medicines_ibfk_1` FOREIGN KEY (`prescription_id`) REFERENCES `prescriptions` (`prescription_id`) ON DELETE CASCADE;

--
-- Constraints for table `reservations`
--
ALTER TABLE `reservations`
  ADD CONSTRAINT `reservations_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`),
  ADD CONSTRAINT `reservations_ibfk_2` FOREIGN KEY (`pharmacy_id`) REFERENCES `pharmacies` (`pharmacy_id`),
  ADD CONSTRAINT `reservations_ibfk_3` FOREIGN KEY (`prescription_medicine_id`) REFERENCES `prescription_medicines` (`id`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
