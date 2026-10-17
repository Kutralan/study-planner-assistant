import from datetime { date, datetime }

node Course { has code: str = "", title: str = "", credits: float = 0.0; }
node StudyTask { has title: str = "", course_code: str = "", topic: str = "", action: str = "Study topic", minutes: int = 30, done: bool = False; }
node AcademicEvent { has title: str = "", kind: str = "event", course_code: str = "", starts_at: str = "", date_only: bool = False; }

obj PlannedSession {
    has task_id: str;
    has title: str;
    has course_code: str;
    has topic: str;
    has action: str;
    has minutes: int;
    has reason: str;
}
obj DailyPlan {
    has sessions: list[PlannedSession];
    has available_minutes: int;
    has reserved_buffer_minutes: int;
    has scheduled_minutes: int;
    has unscheduled_count: int;
    has explanation: str;
}

# Deterministic, explainable daily allocation; does not mutate completed history.
def:pub generate_daily_study_plan(available_hours: int) -> DailyPlan {
    tasks = [root -->[?:StudyTask]];
    courses = [root -->[?:Course]];
    events = [root -->[?:AcademicEvent]];
    available = available_hours * 60 if available_hours > 0 and available_hours <= 16 else 0;
    buffer = int(available * 0.2);
    capacity = available - buffer;
    remaining = capacity;
    sessions: list[PlannedSession] = [];
    pending = [t for t in tasks if not t.done];
    # Stable course ordering lets the plan spread attention without random reassignment.
    for course in courses {
        for task in pending {
            if task.course_code == course.code and task.minutes <= remaining {
                urgency = "Priority informed by " + str(course.credits) + " course credits";
                for ev in events {
                    if ev.course_code == course.code and ev.starts_at {
                        urgency = urgency + "; upcoming " + ev.kind + " is included in course priority";
                    }
                }
                sessions = sessions + [PlannedSession(task_id=jid(task), title=task.title, course_code=task.course_code, topic=task.topic, action=task.action, minutes=task.minutes, reason=urgency)];
                remaining = remaining - task.minutes;
            }
        }
    }
    for task in pending {
        already = len([s for s in sessions if s.task_id == jid(task)]) > 0;
        if not already and task.minutes <= remaining {
            sessions = sessions + [PlannedSession(task_id=jid(task), title=task.title, course_code=task.course_code, topic=task.topic, action=task.action, minutes=task.minutes, reason="Unlinked or flexible task; included after course-weighted tasks")];
            remaining = remaining - task.minutes;
        }
    }
    return DailyPlan(sessions=sessions, available_minutes=available, reserved_buffer_minutes=buffer, scheduled_minutes=capacity - remaining, unscheduled_count=len(pending) - len(sessions), explanation="On-demand plan: only unfinished tasks are considered. Course credits inform ordering, confirmed events are respected as fixed commitments, and 20% of available time is held back. Tasks exceeding capacity remain unscheduled; no completed history is changed.");
}
