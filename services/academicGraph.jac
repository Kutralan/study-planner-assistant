node StudentProfile {
    has university: str = "";
    has faculty: str = "";
    has department: str = "";
    has batch: str = "";
    has semester: str = "";
    has timezone: str = "UTC";
    has weekly_hours: int = 12;
}

node Course {
    has code: str;
    has title: str;
    has credits: float = 0.0;
}

node AcademicEvent {
    has title: str;
    has kind: str = "event";
    has course_code: str = "";
    has starts_at: str = "";
    has ends_at: str = "";
    has date_only: bool = False;
    has venue: str = "";
    has source: str = "manual";
    has verified: bool = True;
}

node StudyTask {
    has title: str;
    has course_code: str = "";
    has topic: str = "";
    has action: str = "Study topic";
    has minutes: int = 30;
    has done: bool = False;
}

edge ProfileCourse: StudentProfile --> Course {}
edge ProfileEvent: StudentProfile --> AcademicEvent {}
edge ProfileTask: StudentProfile --> StudyTask {}

obj WorkspaceView {
    has configured: bool;
    has university: str;
    has faculty: str;
    has department: str;
    has batch: str;
    has semester: str;
    has timezone: str;
    has weekly_hours: int;
    has courses: list[dict];
    has events: list[dict];
    has tasks: list[dict];
    has complete_count: int;
}

def _profile() -> StudentProfile | None {
    found = [root -->][?:StudentProfile];
    if len(found) > 0 { return found[0]; }
    return None;
}

def:pub workspace() -> WorkspaceView {
    p = _profile();
    if p is None {
        return WorkspaceView(configured=False, university="", faculty="", department="", batch="", semester="", timezone="UTC", weekly_hours=12, courses=[], events=[], tasks=[], complete_count=0);
    }
    courses: list[dict] = [];
    for c in [p ->:ProfileCourse:->][?:Course] { courses = courses + [{"code": c.code, "title": c.title, "credits": c.credits}]; }
    events: list[dict] = [];
    for e in [root -->][?:AcademicEvent] { events = events + [{"title": e.title, "kind": e.kind, "course_code": e.course_code, "starts_at": e.starts_at, "date_only": e.date_only, "venue": e.venue, "verified": e.verified}]; }
    tasks: list[dict] = [];
    complete_count = 0;
    for t in [root -->][?:StudyTask] {
        tasks = tasks + [{"id": jid(t), "title": t.title, "course_code": t.course_code, "topic": t.topic, "action": t.action, "minutes": t.minutes, "done": t.done}];
        if t.done { complete_count = complete_count + 1; }
    }
    return WorkspaceView(configured=True, university=p.university, faculty=p.faculty, department=p.department, batch=p.batch, semester=p.semester, timezone=p.timezone, weekly_hours=p.weekly_hours, courses=courses, events=events, tasks=tasks, complete_count=complete_count);
}

def:pub save_profile(university: str, faculty: str, department: str, batch: str, semester: str, timezone: str, weekly_hours: int) -> bool {
    if not university.strip() or not semester.strip() or weekly_hours < 1 or weekly_hours > 80 { return False; }
    p = _profile();
    if p is None { p = root ++> StudentProfile(university=university.strip(), faculty=faculty.strip(), department=department.strip(), batch=batch.strip(), semester=semester.strip(), timezone=timezone.strip(), weekly_hours=weekly_hours); }
    else {
        p.university = university.strip(); p.faculty = faculty.strip(); p.department = department.strip(); p.batch = batch.strip(); p.semester = semester.strip(); p.timezone = timezone.strip(); p.weekly_hours = weekly_hours;
    }
    return True;
}

def:pub add_course(code: str, title: str, credits: float) -> bool {
    p = _profile();
    if p is None or not code.strip() or not title.strip() or credits <= 0 or credits > 40 { return False; }
    for c in [p ->:ProfileCourse:->][?:Course] { if c.code == code.strip() { c.title = title.strip(); c.credits = credits; return True; } }
    fresh = Course(code=code.strip(), title=title.strip(), credits=credits);
    p +>:ProfileCourse:+> fresh;
    return True;
}

def:pub add_item(kind: str, title: str, course_code: str, date_value: str, time_value: str, venue: str, topic: str, minutes: int) -> bool {
    p = _profile();
    if p is None or not title.strip() { return False; }
    if kind == "task" {
        if minutes < 5 or minutes > 600 { return False; }
        fresh_task = root ++> StudyTask(title=title.strip(), course_code=course_code.strip(), topic=topic.strip(), action="Study " + topic.strip() if topic.strip() else "Review course notes", minutes=minutes);
        return len([root -->][?:StudyTask]) > 0;
    }
    if kind == "lecture" or kind == "exam" or kind == "quiz" or kind == "assignment" or kind == "holiday" or kind == "event" {
        fresh_event = root ++> AcademicEvent(title=title.strip(), kind=kind, course_code=course_code.strip(), starts_at=date_value.strip() + ("T" + time_value.strip() if time_value.strip() else ""), date_only=not time_value.strip(), venue=venue.strip(), verified=True);
        return True;
    }
    return False;
}

def:pub complete_task(task_id: str, done: bool) -> bool {
    p = _profile();
    if p is None { return False; }
    for t in [root -->][?:StudyTask] { if jid(t) == task_id { t.done = done; return True; } }
    return False;
}
