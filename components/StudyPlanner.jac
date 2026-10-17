import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { BookOpen01Icon, Calendar03Icon, Task01Icon, Analytics01Icon, SparklesIcon, Add01Icon, CheckmarkCircle02Icon }
import from .ui.card { Card, CardHeader, CardTitle, CardDescription, CardContent }
import from .ui.button { Button }
import from .ui.badge { Badge }
import from .ui.progress { Progress }
import from .ui.input { Input }
import from "@jac/runtime" { jacLogin, jacSignup, jacLogout, jacIsLoggedIn }
sv import from ..services.academicGraph { WorkspaceView, workspace, save_profile, add_course, add_item, complete_task }
sv import from ..services.geminiService { respond_with_gemini }

def:pub StudyPlanner() -> JsxElement {
    has data: WorkspaceView | None = None;
    has loading: bool = True;
    has message_error: str = "";
    has email: str = "";
    has password: str = "";
    has auth_message: str = "";
    has university: str = "";
    has faculty: str = "";
    has department: str = "";
    has batch: str = "";
    has semester: str = "";
    has timezone: str = "UTC";
    has hours: str = "12";
    has course_code: str = "";
    has course_title: str = "";
    has credits: str = "3";
    has task_title: str = "";
    has task_course: str = "";
    has task_topic: str = "";
    has task_minutes: str = "30";
    has event_date: str = "";
    has event_time: str = "";
    has event_venue: str = "";
    has course_choice: str = "";
    has chat_text: str = "";
    has chat_messages: list[dict] = [];
    has chat_busy: bool = False;
    has upload_records: list[dict] = [];

    async def refresh_workspace() {
        loading = True;
        message_error = "";
        try {
            data = await workspace();
            if data is not None {
                university = data.university;
                faculty = data.faculty;
                department = data.department;
                batch = data.batch;
                semester = data.semester;
                timezone = data.timezone;
                hours = str(data.weekly_hours);
            }
        } except Exception { message_error = "Unable to load your private academic records. Check your session and retry."; }
        loading = False;
    }

    async can with entry {
        if jacIsLoggedIn() { await refresh_workspace(); }
        else { loading = False; }
    }

    def set_email(e: ChangeEvent) { email = e.target.value; }
    def set_password(e: ChangeEvent) { password = e.target.value; }
    def set_university(e: ChangeEvent) { university = e.target.value; }
    def set_faculty(e: ChangeEvent) { faculty = e.target.value; }
    def set_department(e: ChangeEvent) { department = e.target.value; }
    def set_batch(e: ChangeEvent) { batch = e.target.value; }
    def set_semester(e: ChangeEvent) { semester = e.target.value; }
    def set_timezone(e: ChangeEvent) { timezone = e.target.value; }
    def set_hours(e: ChangeEvent) { hours = e.target.value; }
    def set_course_code(e: ChangeEvent) { course_code = e.target.value; }
    def set_course_title(e: ChangeEvent) { course_title = e.target.value; }
    def set_credits(e: ChangeEvent) { credits = e.target.value; }
    def set_task_title(e: ChangeEvent) { task_title = e.target.value; }
    def set_task_course(e: ChangeEvent) { task_course = e.target.value; }
    def set_task_topic(e: ChangeEvent) { task_topic = e.target.value; }
    def set_task_minutes(e: ChangeEvent) { task_minutes = e.target.value; }
    def set_event_date(e: ChangeEvent) { event_date = e.target.value; }
    def set_event_time(e: ChangeEvent) { event_time = e.target.value; }
    def set_event_venue(e: ChangeEvent) { event_venue = e.target.value; }
    def set_chat_text(e: ChangeEvent) { chat_text = e.target.value; }

    async def sign_in() {
        try {
            ok: bool = False;
            ok = await jacLogin(email, password);
            if ok { await refresh_workspace(); } else { auth_message = "Sign in failed. Check the email and password."; }
        } except Exception { auth_message = "Sign in failed. Check the email and password."; }
    }
    async def register() {
        try {
            result: dict | None = None;
            logged: bool = False;
            result = await jacSignup(email, password);
            if result["success"] {
                logged = await jacLogin(email, password);
                if logged { await refresh_workspace(); } else { auth_message = "Account created. Sign in to continue."; }
            } else { auth_message = str(result["error"] or "Could not create the account."); }
        } except Exception { auth_message = "Could not create account. Use a valid email and a unique password."; }
    }
    async def save_profile_click() {
        try {
            result_ok: bool = False;
            result_ok = await save_profile(university, faculty, department, batch, semester, timezone, int(hours));
            if result_ok { await refresh_workspace(); } else { message_error = "University, semester, and 1–80 weekly study hours are required."; }
        } except Exception { message_error = "Profile could not be saved. Check fields and retry."; }
    }
    async def add_course_click() {
        try {
            result_ok: bool = False;
            result_ok = await add_course(course_code, course_title, float(credits));
            if result_ok { course_code = ""; course_title = ""; await refresh_workspace(); } else { message_error = "Enter a unique course code, title, and credits between 0 and 40."; }
        } except Exception { message_error = "Course could not be saved."; }
    }
    async def add_task_click() {
        try {
            result_ok: bool = False;
            result_ok = await add_item("task", task_title, task_course, "", "", "", task_topic, int(task_minutes));
            if result_ok { task_title = ""; await refresh_workspace(); } else { message_error = "Enter a task title and a duration between 5 and 600 minutes."; }
        } except Exception { message_error = "Study task could not be saved."; }
    }
    async def add_event_click() {
        try {
            result_ok: bool = False;
            result_ok = await add_item("lecture", task_title, task_course, event_date + ("T" + event_time if event_time else ""), event_time, event_venue, "", 0);
            if result_ok { task_title = ""; await refresh_workspace(); } else { message_error = "Enter a lecture title and date."; }
        } except Exception { message_error = "Lecture could not be saved."; }
    }
    async def toggle_task(task_id: str, previous: bool) {
        try {
            changed: bool = False;
            changed = await complete_task(task_id, not previous);
            if changed { await refresh_workspace(); } else { message_error = "Could not update the task status."; }
        } except Exception { message_error = "Task completion could not be saved."; }
    }
    def remove_attachment(index: int) {
        remaining: list[dict] = [];
        for (i, record) in enumerate(upload_records) { if i != index { remaining = remaining + [record]; } }
        upload_records = remaining;
    }
    async def add_attachment(e: ChangeEvent) {
        chosen: any = e.target.files[0];
        if chosen {
            if chosen.size > 10485760 {
                upload_records = upload_records + [{"name": chosen.name, "content": "", "state": "Too large (10 MB maximum)"}];
            } elif chosen.type == "text/plain" or chosen.name.endswith(".txt") or chosen.name.endswith(".csv") {
                text = await chosen.text();
                upload_records = upload_records + [{"name": chosen.name, "content": text, "state": "Text extracted locally; not sent"}];
            } elif chosen.type == "application/pdf" or chosen.name.endswith(".pdf") {
                try {
                    doc_data = await chosen.arrayBuffer();
                    pdf_raw = await getDocument({"data": doc_data}).promise;
                    pdf: any = pdf_raw;
                    page_count: int = pdf.numPages as int;
                    if page_count > 60 { upload_records = upload_records + [{"name": chosen.name, "content": "", "state": "PDF exceeds 60 pages"}]; }
                    else {
                        body: str = "";
                        for n in range(1, page_count + 1) {
                            page = await pdf.getPage(n);
                            page_body = await page.getTextContent();
                            for fragment in page_body.items { fragment_value: any = fragment; if fragment_value.str { body = body + str(fragment_value.str) + " "; } }
                            body = body + "\n";
                        }
                        await pdf.destroy();
                        state = "PDF text extracted locally; not sent" if body.strip() else "No selectable PDF text; image scans require OCR";
                        upload_records = upload_records + [{"name": chosen.name, "content": body, "state": state}];
                    }
                } except Exception { upload_records = upload_records + [{"name": chosen.name, "content": "", "state": "PDF extraction failed"}]; }
            } elif chosen.type == "image/png" or chosen.type == "image/jpeg" or chosen.name.endswith(".png") or chosen.name.endswith(".jpg") or chosen.name.endswith(".jpeg") {
                try {
                    worker = await createWorker("eng");
                    recognized = await worker.recognize(chosen);
                    await worker.terminate();
                    image_body = str(recognized.data.text);
                    image_state = "Image OCR extracted locally; not sent" if image_body.strip() else "No readable text detected";
                    upload_records = upload_records + [{"name": chosen.name, "content": image_body, "state": image_state}];
                } except Exception { upload_records = upload_records + [{"name": chosen.name, "content": "", "state": "Image OCR failed"}]; }
            } else { upload_records = upload_records + [{"name": chosen.name, "content": "", "state": "Unsupported format"}]; }
        }
    }
    async def send_message() {
        if chat_text.strip() and not chat_busy {
            chat_busy = True;
            prompt = chat_text.strip();
            extracted = "";
            for file in upload_records { if file["content"] and file["state"].endswith("not sent") { extracted = extracted + "\n[Approved note text: " + str(file["name"]) + "]\n" + str(file["content"]); } }
            history_next = chat_messages + [{"role": "student", "text": prompt}];
            chat_messages = history_next;
            context = "";
            for turn in history_next { context = context + str(turn["role"]) + ": " + str(turn["text"]) + "\n"; }
            chat_text = "";
            try {
                reply = await respond_with_gemini(prompt + extracted, context);
                chat_messages = chat_messages + [{"role": "assistant", "text": reply}];
                sent_records: list[dict] = [];
                for file in upload_records { if file["content"] and file["state"].endswith("not sent") { sent_records = sent_records + [{**file, "state": "Sent as extracted text"}]; } else { sent_records = sent_records + [file]; } }
                upload_records = sent_records;
            } except Exception { message_error = "Assistant request failed. Check Gemini configuration and retry."; }
            chat_busy = False;
        }
    }

    if not jacIsLoggedIn() {
        return <div className="grid min-h-screen bg-muted/40 lg:grid-cols-2"><section className="hidden flex-col justify-between bg-primary p-12 text-primary-foreground lg:flex"><div className="flex items-center gap-3"><HugeiconsIcon icon={BookOpen01Icon} strokeWidth={2} className="size-6" /><div><p className="text-lg font-semibold">Daymark</p><p className="text-sm">University Academic Assistant</p></div></div><div><h1 className="text-4xl font-semibold">Plan your semester with clarity.</h1><p className="mt-4 max-w-md">Keep your courses, lectures, and study tasks organized in a private academic workspace.</p></div><p className="text-sm">Never reuse your university portal password.</p></section><main className="flex min-h-screen items-center justify-center p-6"><Card className="w-full max-w-md shadow-sm"><CardHeader><CardTitle>Sign in or create your account</CardTitle><CardDescription>Your academic records are private to your account.</CardDescription></CardHeader><CardContent className="flex flex-col gap-3"><label>Email</label><Input type="email" value={email} onChange={set_email} placeholder="you@university.edu" /><label>Password</label><Input type="password" value={password} onChange={set_password} placeholder="Create a unique password" /><p role="alert" className="text-sm text-destructive">{auth_message}</p><div className="flex gap-2"><Button className="flex-1" onClick={sign_in}>Sign in</Button><Button variant="outline" className="flex-1" onClick={register}>Create account</Button></div><p className="text-xs text-muted-foreground">Jac built-in account service. Do not use your university portal password.</p></CardContent></Card></main></div>;
    }
    if loading { return <div className="flex min-h-screen items-center justify-center bg-muted/40"><Card className="p-8 text-muted-foreground">Loading your private academic workspace…</Card></div>; }
    configured = data is not None and data.configured;
    course_total = len(data.courses) if data is not None else 0;
    event_total = len(data.events) if data is not None else 0;
    task_total = len(data.tasks) if data is not None else 0;
    done_total = data.complete_count if data is not None else 0;
    progress_percent = int(done_total * 100 / task_total) if task_total > 0 else 0;
    university_label = "Academic workspace";
    semester_label = "Setup";
    unit_label = "Profile and courses";
    if data is not None { university_label = data.university; semester_label = data.semester; unit_label = data.faculty + " · " + data.department; }

    return <div className="min-h-screen bg-muted/40"><div className="mx-auto flex min-h-screen w-full max-w-[1600px]"><aside className="hidden w-60 shrink-0 flex-col border-r bg-card px-4 py-6 lg:flex"><div className="mb-9 flex items-center gap-3 px-2"><div className="flex size-9 items-center justify-center rounded-xl bg-primary text-primary-foreground"><HugeiconsIcon icon={BookOpen01Icon} strokeWidth={2} className="size-5" /></div><div><p className="font-semibold">Daymark</p><p className="text-xs text-muted-foreground">Academic workspace</p></div></div><p className="mb-2 px-3 text-xs text-muted-foreground">WORKSPACE</p><nav className="flex flex-col gap-1"><a href="#home" className="rounded-lg bg-primary/10 px-3 py-2 text-sm text-primary">Dashboard</a><a href="#events" className="rounded-lg px-3 py-2 text-sm text-muted-foreground">Calendar</a><a href="#tasks" className="rounded-lg px-3 py-2 text-sm text-muted-foreground">Study plan</a><a href="#knowledge" className="rounded-lg px-3 py-2 text-sm text-muted-foreground">Courses & graph</a></nav><div className="mt-auto rounded-xl border bg-muted/40 p-4 text-xs text-muted-foreground">Private graph records. External providers are not connected.</div></aside><main className="min-w-0 flex-1"><header className="sticky top-0 z-10 flex h-16 items-center justify-between border-b bg-background/95 px-4 sm:px-7"><div className="font-medium">{university_label} · {semester_label}</div><div className="flex items-center gap-3 text-sm"><span className="text-muted-foreground">{data.timezone if data is not None else "UTC"}</span><Button size="sm" variant="outline" onClick={lambda { jacLogout(); data = None; }}>Sign out</Button></div></header><div className="flex flex-col gap-5 p-4 sm:p-6 xl:p-8"><div id="home" className="flex flex-wrap items-end justify-between gap-3"><div><p className="text-sm text-muted-foreground">{unit_label}</p><h1 className="text-2xl font-semibold">{semester_label + " study dashboard" if configured else "Set up your academic workspace"}</h1><p className="text-sm text-muted-foreground">Your saved courses, calendar, and checklist. No sample deadlines are shown.</p></div><Badge variant="outline">Private graph · signed in</Badge></div>{if message_error {<p role="alert" className="rounded-md bg-destructive/10 p-3 text-sm text-destructive">{message_error}</p>}}{if not configured {<Card><CardHeader><CardTitle>Student profile</CardTitle><CardDescription>Set your university, term, timezone, and weekly study capacity.</CardDescription></CardHeader><CardContent className="grid gap-3 sm:grid-cols-2"><label>University<Input value={university} onChange={set_university} placeholder="University" /></label><label>Faculty<Input value={faculty} onChange={set_faculty} placeholder="Faculty" /></label><label>Department<Input value={department} onChange={set_department} placeholder="Department" /></label><label>Batch<Input value={batch} onChange={set_batch} placeholder="Batch or intake" /></label><label>Semester<Input value={semester} onChange={set_semester} placeholder="Semester 1" /></label><label>Timezone<Input value={timezone} onChange={set_timezone} placeholder="Asia/Colombo" /></label><label>Weekly available study hours<Input type="number" value={hours} onChange={set_hours} /></label><Button className="self-end" onClick={save_profile_click}>Save profile</Button></CardContent></Card>}}<div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4"><Card><CardContent className="p-4"><p className="text-xs text-muted-foreground">Courses</p><p className="text-2xl font-semibold">{str(course_total)}</p></CardContent></Card><Card><CardContent className="p-4"><p className="text-xs text-muted-foreground">Academic events</p><p className="text-2xl font-semibold">{str(event_total)}</p></CardContent></Card><Card><CardContent className="p-4"><p className="text-xs text-muted-foreground">Study tasks done</p><p className="text-2xl font-semibold">{str(done_total)} / {str(task_total)}</p></CardContent></Card><Card><CardContent className="p-4"><p className="text-xs text-muted-foreground">Checklist completion</p><p className="text-2xl font-semibold">{str(progress_percent)}%</p></CardContent></Card></div><div className="grid gap-5 xl:grid-cols-[minmax(0,1fr)_340px]"><div className="flex min-w-0 flex-col gap-5"><Card id="courses"><CardHeader><CardTitle>Courses and credit weights</CardTitle><CardDescription>Credits are a workload input, not a fixed hour conversion.</CardDescription></CardHeader><CardContent className="flex flex-col gap-3"><div className="grid gap-2 sm:grid-cols-[1fr_1fr_120px_auto]"><Input aria-label="Course code" placeholder="Course code" value={course_code} onChange={set_course_code} /><Input aria-label="Course name" placeholder="Course name" value={course_title} onChange={set_course_title} /><Input aria-label="Credits" type="number" value={credits} onChange={set_credits} /><Button onClick={add_course_click}>Add course</Button></div>{if course_total == 0 {<p className="rounded-lg border border-dashed p-4 text-sm text-muted-foreground">No courses added. Start with a course code, name, and credit value.</p>}}{if data is not None {for course in data.courses {<div key={course.code} className="flex justify-between rounded-lg border bg-card p-3 text-sm"><span><strong>{course.code}</strong> · {course.title}</span><span>{str(course.credits)} credits</span></div>}}}</CardContent></Card><Card id="events"><CardHeader><CardTitle>Academic calendar and timetable</CardTitle><CardDescription>Date-only entries are shown without an invented time. Venue text is student-supplied.</CardDescription></CardHeader><CardContent className="grid gap-2 sm:grid-cols-2"><Input aria-label="Event or lecture title" placeholder="Lecture, quiz, exam, assignment" value={task_title} onChange={set_task_title} /><div className="flex h-10 items-center rounded-md border bg-muted/30 px-3 text-sm">Lecture timetable entry</div><Input aria-label="Course code" placeholder="Course code (optional)" value={task_course} onChange={set_task_course} /><Input aria-label="Event date" type="date" value={event_date} onChange={set_event_date} /><Input aria-label="Start time" type="time" value={event_time} onChange={set_event_time} /><Input aria-label="Venue" placeholder="Venue / room" value={event_venue} onChange={set_event_venue} /><Button onClick={add_event_click}><HugeiconsIcon icon={Calendar03Icon} strokeWidth={2} className="mr-2 size-4" />Add event</Button>{if event_total == 0 {<p className="rounded-lg border border-dashed p-3 text-sm text-muted-foreground">No confirmed events yet. Upload extraction and countdowns will be added after manual dates are verified.</p>}}{if data is not None {for (i, ev) in enumerate(data.events) {<div key={str(i)} className="rounded-lg border p-3"><p className="font-medium">{ev.title}</p><p className="text-xs text-muted-foreground">{ev.kind} · {ev.course_code} · {ev.starts_at if ev.starts_at else "Date not set"} · {ev.venue if ev.venue else "Venue not provided"}</p></div>}}}</CardContent></Card><Card id="tasks"><CardHeader><CardTitle>Study checklist</CardTitle><CardDescription>Task completion tracks activity, not mastery or submission.</CardDescription></CardHeader><CardContent className="flex flex-col gap-3"><div className="grid gap-2 sm:grid-cols-[1fr_1fr_120px_auto]"><Input aria-label="Study task title" placeholder="Specific study action" value={task_title} onChange={set_task_title} /><Input aria-label="Course code" placeholder="Course code" value={task_course} onChange={set_task_course} /><Input aria-label="Minutes" type="number" value={task_minutes} onChange={set_task_minutes} /><Button onClick={add_task_click}><HugeiconsIcon icon={Add01Icon} strokeWidth={2} className="mr-1 size-4" />Add task</Button></div><Input aria-label="Topic for study task" placeholder="Syllabus topic / note section" value={task_topic} onChange={set_task_topic} />{if task_total == 0 {<p className="rounded-lg border border-dashed p-4 text-sm text-muted-foreground">No study tasks yet. Add a concrete action, topic, and duration.</p>}}{if data is not None {for task in data.tasks {<button key={task["id"]} onClick={lambda { toggle_task(task["id"], task["done"] as bool); }} className="flex items-start gap-3 rounded-lg border p-3 text-left hover:bg-muted/40"><span className={"mt-0.5 flex size-5 items-center justify-center rounded-full border " + ("border-primary bg-primary text-primary-foreground" if task["done"] else "border-border")}>{task["done"] and <HugeiconsIcon icon={CheckmarkCircle02Icon} strokeWidth={2} className="size-4" />}</span><span className="flex-1"><span className="block text-sm font-medium">{task["title"]}</span><span className="text-xs text-muted-foreground">{task["course_code"]} · {task["topic"]} · {task["action"]} · {str(task["minutes"])} min</span></span><Badge variant="outline">{"Completed" if task["done"] else "Not started"}</Badge></button>}}}</CardContent></Card><Card id="knowledge"><CardHeader><CardTitle>Forward-directed study map</CardTitle><CardDescription>Course nodes connect to study tasks and extracted topics as those records are added.</CardDescription></CardHeader><CardContent className="flex flex-col gap-2">{if course_total == 0 {<p className="text-sm text-muted-foreground">Add courses to begin the academic graph.</p>}}{if data is not None {for course in data.courses {<div key={course.code} className="grid grid-cols-[minmax(0,1fr)_24px_minmax(0,1fr)] items-center gap-2 text-sm"><span className="rounded-md border bg-primary/5 p-3"><strong>{course.code}</strong><br/>{course.title}<br/>{str(course.credits)} credits</span><span className="text-center text-primary">→</span><span className="rounded-md border bg-card p-3">{task_total} saved study tasks / topic links</span></div>}}}</CardContent></Card></div><aside className="flex min-w-0 flex-col gap-4" aria-label="Academic assistant"><Card className="flex flex-col shadow-sm xl:sticky xl:top-20"><CardHeader><div className="flex items-center gap-3"><div className="flex size-9 items-center justify-center rounded-lg bg-primary/10 text-primary"><HugeiconsIcon icon={SparklesIcon} strokeWidth={2} className="size-5" /></div><div><CardTitle>Academic assistant</CardTitle><CardDescription>Ask about your private saved workspace</CardDescription></div></div></CardHeader><CardContent className="flex flex-col gap-3"><div className="max-h-64 min-h-28 overflow-y-auto rounded-lg border bg-muted/30 p-3">{if len(chat_messages) == 0 {<p className="rounded-lg bg-card p-3 text-sm">I can explain your saved records. File text is sent only when you choose Send.</p>}}{for (i, msg) in enumerate(chat_messages) {<p key={str(i)} className={"mb-2 rounded-lg p-3 text-sm " + ("ml-4 bg-primary text-primary-foreground" if msg["role"] == "student" else "mr-4 bg-card")}>{msg["text"]}</p>}}</div><p className="text-xs text-muted-foreground">Attachment-to-course linking will be available after course selection is fully wired.</p><label htmlFor="academic-file" className="text-xs font-medium">Attach PDF, image, TXT, or CSV</label><input id="academic-file" type="file" accept=".pdf,.png,.jpg,.jpeg,.txt,.csv" onChange={add_attachment} className="block w-full rounded-md border px-2 py-2 text-xs file:mr-2 file:rounded file:border-0 file:bg-primary file:px-3 file:py-1 file:text-primary-foreground" />{for (i, f) in enumerate(upload_records) {<div key={str(i)} className="flex items-center justify-between gap-2 rounded border p-2 text-xs"><span>{f["name"]} · {f["state"]}</span><button onClick={lambda { remove_attachment(i); }}>Remove</button></div>}}<Input aria-label="Message the academic assistant" placeholder="Ask about my plan or notes" value={chat_text} onChange={set_chat_text} /><div className="flex justify-between text-xs text-muted-foreground"><span>No chat history is saved</span><Button size="sm" disabled={chat_busy} onClick={send_message}>{"Thinking…" if chat_busy else "Send"}</Button></div><p className="text-xs text-muted-foreground">Drive, WhatsApp/email reminders, campus routing, and university submission are not connected.</p></CardContent></Card></aside></div><footer className="border-t pt-4 text-xs text-muted-foreground">Phase 1 · Private persistent academic graph · No external integrations connected</footer></div></main></div></div>;
}
