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
('8d09544c-3cc1-11f1-b1ec-70089427b150', '3', 'Panadol 500mg', 'Paracetamol', 'PAN2024020', '2025-11-30', 50, 9.00, 1, '2026-04-20 14:02:21');

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
('1', 'Wellness Pharmacy', '123 Main Street, Cairo', 30.04440000, 31.23570000, '1234567890', '09:00:00', '23:00:00', 0, 1, 4.50, '2'),
('10', 'Zamalek Pharmacy', '26 July Street, Zamalek, Cairo', 30.06440000, 31.21670000, '0227355678', '09:00:00', '23:00:00', 0, 1, 4.70, '2'),
('11', 'Maadi Pharmacy', '9 Road 9, Maadi, Cairo', 29.96670000, 31.25000000, '0225256789', '08:00:00', '22:00:00', 0, 1, 4.50, '2'),
('12', 'Heliopolis Pharmacy', '40 El Horreya Street, Heliopolis, Cairo', 30.09000000, 31.33000000, '0224156789', '09:00:00', '21:00:00', 0, 1, 4.40, '2'),
('13', 'El Mohandeseen Pharmacy', '15 Syria Street, Mohandeseen, Giza (Greater Cairo)', 30.04800000, 31.20300000, '0233467890', '08:00:00', '23:00:00', 0, 1, 4.60, '2'),
('14', 'Shobra Pharmacy', '20 Shobra Street, Shobra, Cairo', 30.07500000, 31.24000000, '0222091234', '09:00:00', '22:00:00', 0, 1, 4.10, '2'),
('15', 'Abbassiya Pharmacy', '10 Abbassiya Square, Abbassiya, Cairo', 30.06300000, 31.26800000, '0224822345', '08:30:00', '20:30:00', 0, 0, 4.00, '2'),
('16', 'El Nozha Pharmacy', '5 Nozha Street, Heliopolis, Cairo', 30.09500000, 31.34000000, '0226243456', '09:00:00', '22:00:00', 0, 1, 4.30, '2'),
('17', 'City Stars Pharmacy', 'City Stars Mall, Omar Ibn El Khattab St, Heliopolis, Cairo', 30.10200000, 31.34500000, '0224804567', '10:00:00', '23:00:00', 0, 1, 4.80, '2'),
('18', 'Dokki Pharmacy', '25 Mosadek Street, Dokki, Giza (Greater Cairo)', 30.03700000, 31.21200000, '0233355678', '08:00:00', '21:00:00', 0, 1, 4.20, '2'),
('19', 'Hadayek El Kobba Pharmacy', '8 Hadayek El Kobba Street, Cairo', 30.08200000, 31.29000000, '0225456789', '09:00:00', '22:00:00', 0, 1, 4.40, '2'),
('2', '24x7 Medico', '456 Nile Street, Cairo', 30.04420000, 31.23550000, '1234567891', '00:00:00', '23:59:59', 0, 1, 4.80, '2'),
('20', 'El Demerdash Pharmacy', '15 El Demerdash Street, Cairo', 30.05800000, 31.27000000, '0225797890', '08:00:00', '20:00:00', 0, 0, 4.10, '2'),
('21', 'New Cairo Pharmacy', '55 El Tesseen Street, New Cairo, Cairo', 30.00800000, 31.44100000, '', '09:00:00', '23:00:00', 0, 1, 4.70, '2'),
('22', 'Rehab Pharmacy', 'Gate 5, Rehab City, New Cairo, Cairo', 30.01500000, 31.46000000, '', '09:00:00', '22:00:00', 0, 1, 4.50, '2'),
('23', 'Fifth Settlement Pharmacy', '90 South Tesseen, Fifth Settlement, New Cairo, Cairo', 30.02000000, 31.45000000, '0227890123', '08:30:00', '22:30:00', 0, 1, 4.60, '2'),
('3', 'Health Plus Pharmacy', '789 Pyramids Road, Giza', 29.98700000, 31.21180000, '1234567892', '10:00:00', '22:00:00', 0, 0, 4.20, '2'),
('4', 'Seif Pharmacy', '15 Tahrir Street, Downtown, Cairo', 30.04440000, 31.23570000, '0225751234', '08:00:00', '23:00:00', 0, 1, 4.50, '2'),
('5', 'Ezaby Pharmacy - Ramses', '2 Ramses Street, Ramses Square, Cairo', 30.05660000, 31.23340000, '0225762345', '00:00:00', '23:59:00', 1, 1, 4.80, '2'),
('6', 'El Ezaby Pharmacy - Nasr City', '90 Abbas El Akkad Street, Nasr City, Cairo', 30.06240000, 31.33260000, '0222712345', '09:00:00', '22:00:00', 0, 1, 4.60, '2'),
('7', 'Nile Pharmacy', '35 Kasr El Nile Street, Downtown, Cairo', 30.04550000, 31.23660000, '0225743456', '08:30:00', '21:30:00', 0, 1, 4.40, '2'),
('8', 'Cairo Pharmacy', '12 Adly Street, Downtown, Cairo', 30.04660000, 31.23770000, '0225734567', '09:00:00', '22:00:00', 0, 1, 4.30, '2'),
('9', 'Garden City Pharmacy', '5 Garden City Street, Garden City, Cairo', 30.04000000, 31.22800000, '0227954567', '08:00:00', '20:00:00', 0, 0, 4.20, '2');

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
