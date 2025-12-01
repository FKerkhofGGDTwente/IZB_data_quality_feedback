# Project Overview

This repository contains configuration and reference files used for processing **medewerker** (employee) information and retrieving additional data from the **HPZone API**. It also includes a dimension table for diagnosis classification.

---

## 📄 Files in this Repository

### 1. `medewerkers_email.xlsx`
This Excel file must be filled in manually.

**Purpose:**  
Provides a list of all *medewerkers* (employees) whose data needs to be processed or matched with HPZone data.

**Required Columns:**
- **Name** – Full name of the employee  
- **Email** – Valid email address of the employee  

Make sure all entries are complete and correctly formatted, as this file serves as a primary input for further processing.

---

### 2. `HPZone_fields`
This file contains the predefined list of fields retrieved via the **HPZone API**.

**Purpose:**  
Specifies which data attributes should be queried and extracted from HPZone.  
These fields determine what information is fetched through the API, so they must align with the field names available in HPZone.


---

### 3. `DimensionTable_diagnosisClassification`
This table provides a standardized classification of diagnoses.

**Purpose:**  
Maps each diagnosis to relevant metadata, including whether it represents a **vaccine-preventable disease**.

**Important Columns:**
- **Diagnosis** – Name or code of the diagnosis  
- **Vaccin_preventable_disease** – Yes/No indicator showing whether the diagnosis is vaccine preventable  


---

## 🔗 How the Files Work Together

1. **`medewerkers_email.xlsx`** supplies the list of employees who will be coupled to the HPZone Investigating Officer. The Investigating Officer will receiven an email in case there are cases with suggestions of improvement.  
2. **`HPZone_fields`** defines which data fields will be retrieved from HPZone using the API.  
3. **`DimensionTable_diagnosisClassification`** is used to determine if vaccination with respect to diagnosed should be filled in or not

