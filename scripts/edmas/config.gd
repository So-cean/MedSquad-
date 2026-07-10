extends Node

const API_BASE_URL := "http://127.0.0.1:8000"

const LOCATION_TO_MAP := {
	"ED_ENTRANCE": "MAP_ED_CORE",
	"TRIAGE": "MAP_ED_CORE",
	"WAITING_AREA": "MAP_ED_CORE",
	"DOCTOR": "MAP_ED_CORE",
	"ED_RESUS": "MAP_ED_CORE",
	"LAB": "MAP_DIAGNOSTICS",
	"IMAGING": "MAP_DIAGNOSTICS",
	"DIAGNOSTIC_WAITING": "MAP_DIAGNOSTICS",
	"RESULT_REVIEW": "MAP_DIAGNOSTICS",
	"DISPOSITION": "MAP_DOWNSTREAM",
	"ICU": "MAP_DOWNSTREAM",
	"WARD": "MAP_DOWNSTREAM",
	"ED_BOARDING": "MAP_DOWNSTREAM",
	"DISCHARGE": "MAP_DOWNSTREAM",
}

const LOCATION_TO_MARKER := {
	"ED_ENTRANCE": "Marker_ED_Entrance",
	"TRIAGE": "Marker_Triage",
	"WAITING_AREA": "Marker_Waiting",
	"DOCTOR": "Marker_Doctor",
	"ED_RESUS": "Marker_ED_Resus",
	"LAB": "Marker_Lab",
	"IMAGING": "Marker_Imaging",
	"DIAGNOSTIC_WAITING": "Marker_Diagnostic_Waiting",
	"RESULT_REVIEW": "Marker_Result_Review",
	"DISPOSITION": "Marker_Disposition",
	"ICU": "Marker_ICU",
	"WARD": "Marker_Ward",
	"ED_BOARDING": "Marker_ED_Boarding",
	"DISCHARGE": "Marker_Discharge",
}

