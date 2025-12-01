# Project Overview

This repository contains configuration and reference files used for processing **medewerker** (employee) information and retrieving additional data from the **HPZone API**. It also includes a dimension table for diagnosis classification.

---

## 📄 Files in this Repository

### 1. `medewerkers_email.xlsx`
This Excel file must be filled in manually.

**Purpose:**  
Provides a list of all *medewerkers* (employees) whose data needs to be processed or matched with HPZone data.

**Required Columns:**
- **Name** – Full name of the medewerker  
- **Email** – Valid email address of the medewerker  

Make sure all entries are complete and correctly formatted, as this file serves as a primary input for further processing.

---

### 2. `HPZone_fields`
This file contains the predefined list of fields retrieved via the **HPZone API**.

**Purpose:**  
Specifies which data attributes should be queried and extracted from HPZone.  
These fields determine what information is fetched through the API, so they must align with the field names available in HPZone.

**Notes:**  
- The fields listed here are used programmatically when constructing API requests.  
- Modifying field names may cause mismatches or failed data retrievals.

---

### 3. `DimensionTable_diagnosisClassification`
This table provides a standardized classification of diagnoses.

**Purpose:**  
Maps each diagnosis to relevant metadata, including whether it represents a **vaccine-preventable disease**.

**Important Columns:**
- **Diagnosis** – Name or code of the diagnosis  
- **Vaccin_preventable_disease** – Yes/No indicator showing whether the diagnosis is vaccine preventable  

This dimension table helps ensure consistent reporting and analysis by providing uniform diagnosis classifications.

---

## 🔗 How the Files Work Together

1. **`medewerkers_email.xlsx`** supplies the list of medewerkers whose data will be processed.  
2. **`HPZone_fields`** defines which data points will be retrieved from the HPZone API for each medewerker.  
3. **`DimensionTable_diagnosisClassification`** enriches HPZone data by classifying diagnoses, including whether they are vaccine-preventable.

Together, these files enable structured, reliable processing and classification of medewerker and diagnosis information.

---

If you'd like, I can also add installation/setup instructions, workflow diagrams, or badges for a more complete GitHub README.
