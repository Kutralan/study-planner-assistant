node AcademicProfile {
    has university: str = "";
    has faculty: str = "";
    has department: str = "";
    has batch: str = "";
    has semester: str = "";
    has timezone: str = "UTC";
    has weekly_hours: int = 12;
}

node AcademicCourse {
    has code: str;
    has title: str;
    has credits: float = 0.0;
    has active: bool = True;
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
    has status: str = "scheduled";
}

node StudyTask {
    has title: str;
    has course_code: str = "";
    has topic: str = "";
    has action: str = "Study topic";
    has minutes: int = 30;
    has done: bool = False;
    has priority: str = "normal";
}

node KnowledgeTopic {
    has title: str;
    has course_code: str = "";
    has source: str = "manual";
    has verified: bool = True;
}

edge OwnsCourse: AcademicProfile --> AcademicCourse {}
edge HasEvent: AcademicProfile --> AcademicEvent {}
edge PlansTask: AcademicProfile --> StudyTask {}
edge CoversTopic: AcademicCourse --> KnowledgeTopic {}
edge RelatedTopic: KnowledgeTopic --> KnowledgeTopic { has relation: str = "related"; }

obj CourseView {
    has code: str;
    has title: str;
    has credits: float;
}
obj EventView {
    has title: str;
    has kind: str;
    has course_code: str;
    has starts_at: str;
    has ends_at: str;
    has date_only: bool;
    has venue: str;
    has verified: bool;
    has status: str;
}
obj TaskView {
    has id: str;
    has title: str;
    has course_code: str;
    has topic: str;
    has action: str;
    has minutes: int;
    has done: bool;
    has priority: str;
}
obj TopicView {
    has title: str;
    has course_code: str;
    has source: str;
    has verified: bool;
}
obj AcademicWorkspace {
    has configured: bool;
    has university: str;
    has faculty: str;
    has department: str;
    has batch: str;
    has semester: str;
    has timezone: str;
    has weekly_hours: int;
    has courses: list[CourseView];
    has events: list[EventView];
    has tasks: list[TaskView];
    has topics: list[TopicView];
    has completed_count: int;
    has planned_count: int;
    has completed_minutes: int;
    has planned_minutes: int;
}


def _find_profile() -> AcademicProfile | None {
    profiles = [root -->][?:AcademicProfile];
    if len(profiles) > 0 { return profiles[0]; }
    return None;
}


def:priv get_academic_workspace() -> AcademicWorkspace {
    profile = _find_profile();
    if profile is None {
        return AcademicWorkspace(configured=False, university="", faculty="", department="", batch="", semester="", timezone="UTC", weekly_hours=12, courses=[], events=[], tasks=[], topics=[], completed_count=0, planned_count=0, completed_minutes=0, planned_minutes=0);
    }
    courses = [CourseView(code=c.code, title=c.title, credits=c.credits) for c in [profile ->:OwnsCourse:->][?:AcademicCourse]];
    events = [EventView(title=e.title, kind=e.kind, course_code=e.course_code, starts_at=e.starts_at, ends_at=e.ends_at, date_only=e.date_only, venue=e.venue, verified=e.verified, status=e.status) for e in [profile ->:HasEvent:->][?:AcademicEvent]];
    tasks = [TaskView(id=jid(t), title=t.title, course_code=t.course_code, topic=t.topic, action=t.action, minutes=t.minutes, done=t.done, priority=t.priority) for t in [profile ->:PlansTask:->][?:StudyTask]];
    topics: list[TopicView] = [];
    for course in [profile ->:OwnsCourse:->][?:AcademicCourse] {
        for topic in [course ->:CoversTopic:->][?:KnowledgeTopic] {
            topics = topics + [TopicView(title=topic.title, course_code=topic.course_code, source=topic.source, verified=topic.verified)];
        }
    }
    completed = [t for t in [profile ->:PlansTask:->][?:StudyTask] if t.done];
    completed_minutes = sum([t.minutes for t in completed]);
    planned_minutes = sum([t.minutes for t in [profile ->:PlansTask:->][?:StudyTask]]);
    return AcademicWorkspace(configured=True, university=profile.university, faculty=profile.faculty, department=profile.department, batch=profile.batch, semester=profile.semester, timezone=profile.timezone, weekly_hours=profile.weekly_hours, courses=courses, events=events, tasks=tasks, topics=topics, completed_count=len(completed), planned_count=len(tasks), completed_minutes=completed_minutes, planned_minutes=planned_minutes);
}


def:priv save_academic_setup(university: str, faculty: str, department: str, batch: str, semester: str, timezone: str, weekly_hours: int, courses_json: str) -> bool {
    if len(university.strip()) == 0 or len(semester.strip()) == 0 or weekly_hours < 1 or weekly_hours > 80 { return False; }
    profile = _find_profile();
    if profile is None {
        profile = root ++> AcademicProfile(university=university.strip(), faculty=faculty.strip(), department=department.strip(), batch=batch.strip(), semester=semester.strip(), timezone=timezone.strip(), weekly_hours=weekly_hours);
    } else {
        profile.university = university.strip();
        profile.faculty = faculty.strip();
        profile.department = department.strip();
        profile.batch = batch.strip();
        profile.semester = semester.strip();
        profile.timezone = timezone.strip();
        profile.weekly_hours = weekly_hours;
    }
    try {
        import json;
        rows_raw = json.loads(courses_json);
        if not isinstance(rows_raw, list) { return False; }
        rows = rows_raw as list[dict];
        for row in rows {
            code = str(row.get("code", "")).strip();
            title = str(row.get("title", "")).strip();
            credits = float(row.get("credits", 0));
            if not code or not title or credits <= 0 or credits > 40 { continue; }
            existing = [c for c in [profile ->:OwnsCourse:->][?:AcademicCourse] if c.code == code];
            if len(existing) == 0 {
                new_course = AcademicCourse(code=code, title=title, credits=credits);
                profile +>:OwnsCourse:+> new_course;
            } else {
                existing[0].title = title;
                existing[0].credits = credits;
            }
        }
    } except Exception { return False; }
    return True;
}


def:priv add_academic_item(kind: str, title: str, course_code: str, starts_at: str, ends_at: str, date_only: bool, venue: str, topic: str, action: str, minutes: int, priority: str) -> bool {
    profile = _find_profile();
    if profile is None or len(title.strip()) == 0 { return False; }
    if kind == "task" {
        if minutes < 5 or minutes > 600 { return False; }
        fresh_task = StudyTask(title=title.strip(), course_code=course_code.strip(), topic=topic.strip(), action=action.strip(), minutes=minutes, priority=priority.strip());
        profile +>:PlansTask:+> fresh_task;
        return True;
    }
    if kind == "lecture" or kind == "event" or kind == "quiz" or kind == "exam" or kind == "assignment" or kind == "holiday" {
        fresh_event = AcademicEvent(title=title.strip(), kind=kind, course_code=course_code.strip(), starts_at=starts_at.strip(), ends_at=ends_at.strip(), date_only=date_only, venue=venue.strip(), source="student entry", verified=True, status="scheduled");
        profile +>:HasEvent:+> fresh_event;
        return True;
    }
    return False;
}


def:priv set_study_task_done(task_id: str, done: bool) -> bool {
    profile = _find_profile();
    if profile is None { return False; }
    for task in [profile ->:PlansTask:->][?:StudyTask] {
        if jid(task) == task_id {
            task.done = done;
            return True;
        }
    }
    return False;
}
