import from services.chatService { respond_to_chat }
import from services.academicGraph { WorkspaceView, workspace, save_profile, add_course, add_item, complete_task }
import from services.geminiService { respond_with_gemini }
import ".styles.global.css";
import from "@jac/runtime" { Router, Routes, Route }
import from .components.StudyPlanner { StudyPlanner }

def:pub app() -> JsxElement {
    return <Router><Routes><Route path="/" element={<StudyPlanner />} /></Routes></Router>;
}
