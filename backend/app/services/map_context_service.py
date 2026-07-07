from typing import Dict, List


MAPS: Dict[str, Dict] = {
    "MAP_ED_CORE": {
        "name": "急诊核心区",
        "texture": "assets/maps/normalized/map1_norm.png",
        "bounds": {"x1": 0, "y1": 0, "x2": 1672, "y2": 941},
        "rooms": {
            "ED_ENTRANCE": {"name": "急诊入口", "marker": "Marker_ED_Entrance", "bounds": [140, 170, 230, 250]},
            "TRIAGE": {"name": "分诊台", "marker": "Marker_Triage", "bounds": [270, 170, 350, 250]},
            "WAITING_AREA": {"name": "候诊区", "marker": "Marker_Waiting", "bounds": [390, 170, 480, 250]},
            "DOCTOR": {"name": "医生诊室", "marker": "Marker_Doctor", "bounds": [520, 170, 610, 250]},
            "ED_RESUS": {"name": "抢救区", "marker": "Marker_ED_Resus", "bounds": [650, 170, 740, 250]},
        },
    },
    "MAP_DIAGNOSTICS": {
        "name": "检查检验区",
        "texture": "assets/maps/normalized/map2_norm.png",
        "bounds": {"x1": 0, "y1": 0, "x2": 1672, "y2": 941},
        "rooms": {
            "LAB": {"name": "检验科", "marker": "Marker_Lab", "bounds": [180, 200, 270, 280]},
            "IMAGING": {"name": "影像检查室", "marker": "Marker_Imaging", "bounds": [340, 200, 430, 280]},
            "DIAGNOSTIC_WAITING": {"name": "检查等待区", "marker": "Marker_Diagnostic_Waiting", "bounds": [500, 200, 600, 280]},
            "RESULT_REVIEW": {"name": "结果复核区", "marker": "Marker_Result_Review", "bounds": [660, 200, 760, 280]},
        },
    },
    "MAP_DOWNSTREAM": {
        "name": "去向与处置区",
        "texture": "assets/maps/normalized/map3_norm.png",
        "bounds": {"x1": 0, "y1": 0, "x2": 1672, "y2": 941},
        "rooms": {
            "DISPOSITION": {"name": "处置/去向讨论区", "marker": "Marker_Disposition", "bounds": [180, 220, 270, 300]},
            "ICU": {"name": "ICU", "marker": "Marker_ICU", "bounds": [340, 220, 430, 300]},
            "WARD": {"name": "病房", "marker": "Marker_Ward", "bounds": [500, 220, 600, 300]},
            "ED_BOARDING": {"name": "急诊留观", "marker": "Marker_ED_Boarding", "bounds": [660, 220, 760, 300]},
            "DISCHARGE": {"name": "离院/出院", "marker": "Marker_Discharge", "bounds": [820, 220, 920, 300]},
        },
    },
}

LOCATION_TO_MAP = {
    location: map_id
    for map_id, map_data in MAPS.items()
    for location in map_data["rooms"].keys()
}


ROLE_RESPONSIBILITIES = {
    "triage_nurse": [
        "接收患者主诉，判断紧急程度。",
        "决定是否进入候诊、抢救、医生诊室或检查路径。",
        "只能在分诊/候诊相关区域主动调度患者。",
    ],
    "gastroenterologist": [
        "负责胃病相关病史采集、鉴别诊断、检查建议和用药/饮食解释。",
        "根据症状决定是否需要 LAB、IMAGING 或进一步处置。",
        "给患者输出清晰的下一步医嘱。",
    ],
    "emergency_doctor": [
        "负责急诊整体评估和风险升级。",
        "复核检查结果，决定处置去向。",
    ],
    "emergency_nurse": [
        "负责抢救区接诊、持续监测生命体征、建立基础处置准备。",
        "根据急诊医生指令协调转运、检查和设备使用。",
        "不能独立给出最终诊断或手术决策。",
    ],
    "surgeon": [
        "负责创伤外科会诊、手术适应证判断和手术资源请求。",
        "根据急诊评估、影像结果和生命体征决定手术、ICU或继续观察。",
        "不能替代急诊医生完成入院前整体分诊。",
    ],
    "anesthesiologist": [
        "负责气道、麻醉风险和围手术期生命体征支持评估。",
        "在手术资源启动后配合外科医生完成麻醉准备。",
        "不负责创伤诊断或最终去向决策。",
    ],
    "lab_nurse": [
        "负责检验采样、检验设备使用和报告回传。",
        "不做诊断，只报告检查状态和结果。",
    ],
    "imaging_nurse": [
        "负责影像检查引导和检查状态回传。",
        "不做诊断，只报告检查完成情况。",
    ],
    "patient": [
        "表达症状、病史、担忧和对医嘱的理解。",
        "不能自行生成医学诊断，只反馈自身感受。",
    ],
}


def describe_map_context() -> str:
    lines: List[str] = ["地图与区域范围:"]
    for map_id, map_data in MAPS.items():
        bounds = map_data["bounds"]
        lines.append(f"- {map_id} / {map_data['name']} bounds=({bounds['x1']},{bounds['y1']})-({bounds['x2']},{bounds['y2']})")
        for location, room in map_data["rooms"].items():
            x1, y1, x2, y2 = room["bounds"]
            lines.append(f"  - {location}: {room['name']}, marker={room['marker']}, bounds=({x1},{y1})-({x2},{y2})")
    return "\n".join(lines)


def get_location_map(location_id: str) -> str:
    return LOCATION_TO_MAP.get(location_id, "MAP_ED_CORE")


def get_role_responsibilities(profession: str, actor_type: str) -> List[str]:
    if actor_type == "patient":
        return ROLE_RESPONSIBILITIES["patient"]
    return ROLE_RESPONSIBILITIES.get(profession, ROLE_RESPONSIBILITIES.get(actor_type, []))
