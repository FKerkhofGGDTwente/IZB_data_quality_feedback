# title: Quality check HPzone data using HPzone API
# Author: Floor Kerkhof
# Date: 22-05-2025
# Updated by author: Floor Kerkhof
# Date updated: 17-11-2025
# Let op! Dit script vervangt een rij met een dubbele case identifiër met de laatst toegevoegde data

#### Clear RStudio environment ####
rm(list=ls())  # Empty variable environment
cat("\014")  # Empty console

#### Install and load needed packages if not installed yet ####
pkg_req = c("devtools", "safer", "readxl", "dplyr", "writexl", "stringr", "knitr", "Microsoft365R", "lubridate", "tidyr", "glue")

for (pkg in pkg_req) {
  if (system.file(package = pkg) == "") {
    install.packages(pkg)
  }
  library(pkg, character.only = TRUE)
}

# Install and load custom packages if not installed yet
custom_pkg <- "HPZoneAPI"
if (system.file(package = custom_pkg) == "") {
  devtools::install_github("ggdatascience/HPZoneAPI")
}
library(custom_pkg, character.only = TRUE)
# Update packages installed
# Ctrl + Shift + F10 to restart R-session. Then you can update used packages
# devtools::update_packages()

#### Load custom functions ####
style_html_table <- function(df) {
  # Start table
  html <- "<table style='border-collapse:collapse; width:100%; font-family:Arial, sans-serif; font-size:13px;'>"
  
  # Header
  html <- paste0(
    html,
    "<thead><tr>",
    paste0(
      sprintf("<th style='border:1px solid #666; background-color:#005BA1; color:white; padding:6px;'>%s</th>", names(df)),
      collapse = ""
    ),
    "</tr></thead><tbody>"
  )
  
  # Body rows with zebra stripes
  for(i in seq_len(nrow(df))) {
    bg <- ifelse(i %% 2 == 0, "#F7F7F7", "white")
    row <- df[i, ]
    
    html <- paste0(
      html,
      "<tr style='background-color:", bg, ";'>",
      paste0(
        sprintf("<td style='border:1px solid #666; padding:6px;'>%s</td>", row),
        collapse = ""
      ),
      "</tr>"
    )
  }
  
  # End table
  html <- paste0(html, "</tbody></table>")
  return(html)
}


#### Initialize variables ####
test_email = TRUE
dev_mail <- "[EMAIL]"
backup_mail <- "[EMAIL]"
SUBJECT_EMAIL <- "Verbeter suggesties voor datakwaliteit HPzone"

start_date <- format(Sys.Date() - 365, "%Y-%m-%d") # date last year
end_date <- format(Sys.Date() + 1, "%Y-%m-%d") # date today  (+1 since < end_date instead of <= end_date)

# Filepaths
this_script_filepath <- dirname(rstudioapi::getSourceEditorContext()$path)
relative_filepath_cases_fieldnames <- "HPZone_fields.txt"
relative_filepath_dimensiontable <- "DimensionTable_diagnosisClassification.xlsx"
relative_filepath_contactgegevens <- "medewerkers_email.xlsx"


#### Set-up HPZone API ####
# HPZone_store_credentials() # Ony one time needed to store credentials
HPZone_setup()

# Controleer of API key correct is
tryCatch({
  test_HPZone_token()
}, error = function(e) {
  stop("API key error: ", e$message)
})


#### Load data ####
# Load field names to extract using HPzone API
filepath_cases_fieldnames <- paste0(this_script_filepath, '/', relative_filepath_cases_fieldnames)
lines <- readLines(filepath_cases_fieldnames)
fields <- lines %>%
  paste(collapse = ", ") %>%
  strsplit(",") %>%
  unlist() %>%
  trimws()

# Load dimension table to get vaccin preventable diseases
filepath_dimensiontable <- paste0(this_script_filepath, '/', relative_filepath_dimensiontable)
dimension_table <- read_xlsx(filepath_dimensiontable)

# Load medewerkers email
filepath_contactgegevens <- paste0(this_script_filepath, '/', relative_filepath_contactgegevens)
contactgegevens <- read_xlsx(filepath_contactgegevens)

# Get RVP diseases
RVP_diseases <- dimension_table$Diagnosis[dimension_table$Vaccin_prevetable_disease == TRUE]

# Get data from HPZone using API
tryCatch({
  new_cases <- HPZone_request("cases", fields, where=c("creation_date", ">=", start_date, "creation_date", "<", end_date)) %>%
    HPZone_convert_dates()
}, error = function(e) {
  message("Error retrieving HPZone data via API: ", e$message)
})


#### Data preparation ####
# Rename column names to match manual HPZone export
new_column_names <- gsub("_", " ", names(new_cases))
names(new_cases) <- new_column_names

# Change empty strings or strings with only spaces to NA
new_cases <- new_cases %>%
  mutate(across(where(is.character),
                ~ na_if(trimws(.), "")))

# Infection = Unidentifiable infection eruit halen wanneer time entered < 1 aug 2025
new_cases <- new_cases[!(
  new_cases$`Case creation date` < as.Date("2025-08-01") & 
  new_cases$Infection == 'Unidentifiable infection'
  ),]

# Initiate table with to be corrected cases
results <- data.frame(case_number = double(), message = character(), infection = character(), contactpersoon = character(), stringsAsFactors = FALSE)


#### Data quality rules ####
# BSN cannot be checked using API data
# Reference name, family name, first name cannot be checked using API data

rules <- list(
  # Check if Gender is filled in
  list(condition = is.na(new_cases$Gender), 
       message = "Gender is niet ingevuld"),
  
  # Country of birth is filled in
  list(condition = is.na(new_cases$`Country of birth`), 
       message = "Country of birth is niet ingevuld"),
  
  # Principle contextual setting is filled in
  list(condition = is.na(new_cases$`Principal contextual setting`), 
       message = "Principal contextual setting is niet ingevuld"),
  
  # Status van melding is filled in
  list(condition = is.na(new_cases$`Status van de melding`), 
       message = "Status van de melding is niet ingevuld"),
  
  # Laboratorium waar case gediagnostiseerd is is filled in
  list(condition = is.na(new_cases$`Laboratorium waar de casus gediagnosticeerd is`), 
       message = "Laboratorium waar de casus gediagnosticeerd is niet ingevuld"),
  
  # Check if Hospitalised is filled in
  list(condition = new_cases$Hospitalised == -1, 
       message = "Hospitalised is niet ingevuld"),
  
  # Check if Postcode is filled in
  list(condition = is.na(new_cases$Postcode), 
       message = "Postcode is niet ingevuld"),
  
  # Check if Date of Onset is filled in
  list(condition = is.na(new_cases$`Date of onset`),
       message = "Date of Onset is niet ingevuld"),

  # Check if Datum melding aan de GGD is filled in
  list(condition = is.na(new_cases$`Datum melding aan de ggd`),
       message = "Datum melding aan de GGD is niet ingevuld"),
  
  # Check of Date of Onset is before Datum melding aan de GGD
  list(condition = ifelse(
    !is.na(new_cases$`Date of Onset`) & !is.na(new_cases$`Datum melding aan de GGD`),
    new_cases$`Date of Onset` > new_cases$`Datum melding aan de GGD`,
    FALSE  # Exclude when Date of Onset or Datum melding aan GGD is NA
  ), 
  message = "Eerste ziektedag ligt niet voor melddatum"),
  
  # If Principal contextual setting == ziekenhuisopname OR current location == opgenomen in een ziekenhuis, then must be: hospitalized == ja
  list(condition = !ifelse(
    new_cases$`Principal Contextual Setting` == "Ziekenhuis" | new_cases$`Current Location` == "Opgenomen in ziekenhuis",
    new_cases$`Hospitalised` == 1,
    TRUE  # Exclude when not in hospital
  ), 
  message = "Principal contextual setting is ziekenhuisopname of current location is ziekenhuis, maar hospitalized staat niet op 'ja'"),
  
  # When Status van melding == definitief, then Confidence must be "Confirmed"
  list(condition = !ifelse(
    new_cases$`Status van de melding` == "Definitief" | new_cases$`Status van de melding` == "Gefiatteerd",
    new_cases$`Confidence` == "Confirmed",
    TRUE  # Exclude when Status van de melding is not Definitief or Gefiatteerd
  ), 
  message = "Status van melding is Definitief of Gefiatteerd, maar confidence is niet confirmed"),
  
  # When Diagnosis is Rabies, Confidence must be "Possible"
  list(condition = !ifelse(
    new_cases$`Diagnosis` == "Rabies",
    new_cases$`Confidence` == "Possible",
    TRUE  # Exclude when Diagnosis is not Rabies
  ), 
  message = "Diagnose is Rabies, maar Confidence staat niet op Possible"),
  
  # Reisgeschiedenis mag nooit op onbekend/NA staan bij alles behalve: Pneumococcal infection
  list(condition = ifelse(
    new_cases$Infection != "Pneumococcal infection",
    new_cases$`Recent travel to another country` == "Onbekend" | is.na(new_cases$`Recent travel to another country`),
    FALSE  # Exclude when Infection is not Rabies, Malaria, Legionella or Mpox
  ), 
  message = "Recent travel to another country is niet ingevuld"),
  
  # RVP ziektes, dan vaccinated in respect to diagnosis ingevuld
  list(condition = ifelse(
    new_cases$Diagnosis %in% RVP_diseases,
    is.na(new_cases$`Vaccination Date (if relevant)`),
    FALSE  # Exclude when Diagnosis is not a vaccin preventable disease
  ), 
  message = "RVP ziekte, maar vaccinated in respect to diagnosis is niet ingevuld"),
  
  # If infection is Klebsella pneumoniae / Acinetobacter infection, dan moet ABR op CPE staan
  list(condition = ifelse(
    new_cases$Infection %in% c("Klebsiella infection", "Acinetobacter infection"),
    new_cases$`ABR` == 'CPE',
    FALSE  # Exclude when infection is niet Klebsella pneumoniae or Acinetobacter infection
  ), 
  message = "Klebsella pneumoniae / Acinetobacter infection, maar ABR is niet CPE"),
  
  # Als status van de melding = Definitief/gefiatteerd, dan moet osiris nummer zijn ingevuld
  list(condition = ifelse(
    new_cases$`Status van de melding` %in% c("Definitief", "Gefiatteerd"),
    is.na(new_cases$`Osirisnummer`),
    FALSE  # Exclude when status van de melding is niet definitief/gefiatteerd
  ), 
  message = "Status van de melding is definitief/gefiatteerd, maar osiris nummer is niet ingevuld"),
  
  # Als Datum melding bij de GGD > 3 maanden geleden, dan moet de status op Gesloten staan
  list(condition = ifelse(
    new_cases$`Datum melding aan de ggd` < seq(Sys.Date(), length = 2, by = "-3 months")[2],
    new_cases$`Status` != 'Closed',
    FALSE  # Exclude when de datum melding aan de GGD korter is dan 3 maanden geleden
  ), 
  message = "Datum melding aan de GGD is langer dan 3 maanden geleden en status staat niet op gesloten"),
  
  # Als current location = Overleden, dan moet date of death zijn ingevuld
  list(condition = ifelse(
    new_cases$`Current location` == 'Overleden',
    is.na(new_cases$`Date of death`),
    FALSE  # Exclude when current location is not Overleden
  ), 
  message = "Current location = Overleden, maar date of death is niet ingevuld"),
  
  # Als date of death is ingevuld, dan moet current location = Overleden
  list(condition = ifelse(
    !is.na(new_cases$`Date of death`),
    new_cases$`Current location` != 'Overleden',
    FALSE  # Exclude when current Date of death is null
  ), 
  message = "Date of death is ingevuld, maar current location staat niet op overleden")
)


#### Check data quality rules ####
for(rule in rules){
  cases_failed <- which(rule$condition)
  
  if (length(cases_failed) > 0) {
    for(case in cases_failed){
      results <- bind_rows(results,
                           data.frame(
                              date_case_creation = format(new_cases$`Case creation date`[case], "%d-%m-%Y"),
                              case_number = new_cases$`Case number`[case],
                              message = rule$message,
                              infection = new_cases$Infection[case],
                              contactpersoon = new_cases$`Investigating officer`[case]))
    }
  }
}


#### Collapse messages per Case Number ####
combined_results <- results %>%
  group_by(case_number) %>%
  mutate(messages = paste(unique(message), collapse = "; ")) %>%
  ungroup() %>%
  select(-message)

combined_results_unique <- combined_results[!duplicated(combined_results), ]


final_results <- split(combined_results_unique, combined_results_unique$contactpersoon) %>%
  lapply(\(x) x[ , !names(x) %in% "contactpersoon"]) #Remove column "contactpersoon" from tibble



#### Sent email to case investigating officers ####
outlook <- get_business_outlook()

for(name in names(final_results)) {
  email <- contactgegevens$email[match(name, contactgegevens$medewerker)]
  email <- ifelse(is.na(email), backup_mail, email)

  table_html <- style_html_table(final_results[[name]])
  
  body_message_html <- glue('<html>
  <body style="font-family: Arial, sans-serif; font-size: 14px; color: #333;">
                <p>Dag {name},</p>
                
                <p>
                Dit is een automatisch gestuurd bericht met verbeter suggesties voor de HPzone data kwaliteit.
                </p>
                
                <p>
                Hieronder vind je een overzicht van de HPzone data:
                </p>
                
                {table_html}

                <p>
                Note: dit is een no-reply message.
                Voor vragen kun je terecht bij:
                i.hazelhorst@ggdtwente.nl of f.kerkhof@ggdtwente.nl
                </p>
                
                <p>Met vriendelijke groet,<br>
                GGD Bot</p>
                </body>
                </html>')
  
  if(test_email){
    print('Sent test email to Floor')
    outlook$create_email(
      to = dev_mail,
      subject = SUBJECT_EMAIL,
      body = body_message_html,
      content_type = "html"
    )$send()
  } else {
    print('Sent email to employee')
    outlook$create_email(
      to = email,
      subject = SUBJECT_EMAIL,
      body = body_message_html,
      content_type = "html"
    )$send()
  }

  }









