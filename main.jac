import from services.chatService { respond_to_chat }
import ".styles.global.css";
import from "@jac/runtime" { Router, Routes, Route }
import from .components.StudyPlanner { StudyPlanner }

def:pub app() -> JsxElement {
    return <Router><Routes><Route path="/" element={<StudyPlanner />} /></Routes></Router>;
}
