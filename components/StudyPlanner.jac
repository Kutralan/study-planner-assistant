import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { DashboardSquare01Icon, Calendar03Icon, Task01Icon, Analytics01Icon, Notification01Icon, Clock01Icon, Location01Icon, SparklesIcon, Add01Icon, CheckmarkCircle02Icon, BookOpen01Icon }
import from .ui.card { Card, CardHeader, CardTitle, CardDescription, CardContent }
import from .ui.button { Button }
import from .ui.badge { Badge }
import from .ui.progress { Progress }
import from .ui.input { Input }
import from "pdfjs-dist" { getDocument }
import from "tesseract.js" { createWorker }
import from "@jac/runtime" { jacLogin, jacSignup, jacLogout, jacIsLoggedIn }
sv import from ..services.academicGraph { AcademicWorkspace, get_academic_workspace, save_academic_setup, add_academic_item, set_study_task_done }
sv import from ..services.geminiService { respond_with_gemini }

def:pub StudyPlanner() -> JsxElement {
    has workspace: AcademicWorkspace | None = None;
    has loading: bool = True;
    has page_error: str = "";
    has email: str = "";
    has password: str = "";
    has auth_message: str = "";
    has university: str = "";
    has faculty: str = "";
    has department: str = "";
    has batch: str = "";
    has semester: str = "";
    has timezone: str = "UTC";
    has weekly_hours_text: str = "12";
    has courses_text: str = "";
    has item_title: str = "";
    has item_kind: str = "task";
    has item_course: str = "";
    has item_date: str = "";
    has item_time: str = "";
    has item_venue: str = "";
    has item_minutes_text: str = "30";
    has item_topic: str = "";
    has chat_input: str = "";
    has chat_history: list[dict] = [];
    has chat_error: str = "";
    has chat_busy: bool = False;
    has uploaded_files: list[dict] = [];
    has course_choice: str = "";

    async def load_workspace() {
        loading = True;
        page_error = "";
        try {
            workspace = await get_academic_workspace();
            if workspace is not None {
                university = workspace.university;
                faculty = workspace.faculty;
                department = workspace.department;
                batch = workspace.batch;
                semester = workspace.semester;
                timezone = workspace.timezone;
                weekly_hours_text = str(workspace.weekly_hours);
            }
        } except Exception {
            page_error = "Could not load your private academic workspace. Sign in again and retry.";
        }
        loading = False;
    }

    async can with entry {
        if jacIsLoggedIn() { await load_workspace(); }
        else { loading = False; }
    }

    def handle_email(e: ChangeEvent) { email = e.target.value; }
    def handle_password(e: ChangeEvent) { password = e.target.value; }
    def handle_university(e: ChangeEvent) { university = e.target.value; }
    def handle_faculty(e: ChangeEvent) { faculty = e.target.value; }
    def handle_department(e: ChangeEvent) { department = e.target.value; }
    def handle_batch(e: ChangeEvent) { batch = e.target.value; }
    def handle_semester(e: ChangeEvent) { semester = e.target.value; }
    def handle_timezone(e: ChangeEvent) { timezone = e.target.value; }
    def handle_hours(e: ChangeEvent) { weekly_hours_text = e.target.value; }
    def handle_courses(e: ChangeEvent) { courses_text = e.target.value; }
    def handle_item_title(e: ChangeEvent) { item_title = e.target.value; }
    def handle_item_course(e: ChangeEvent) { item_course = e.target.value; }
    def handle_item_date(e: ChangeEvent) { item_date = e.target.value; }
    def handle_item_time(e: ChangeEvent) { item_time = e.target.value; }
    def handle_item_venue(e: ChangeEvent) { item_venue = e.target.value; }
    def handle_item_minutes(e: ChangeEvent) { item_minutes_text = e.target.value; }
    def handle_item_topic(e: ChangeEvent) { item_topic = e.target.value; }
    def handle_chat_input(e: ChangeEvent) { chat_input = e.target.value; }
    def handle_course_choice(e: ChangeEvent) { course_choice = e.target.value; }
    def handle_kind(e: ChangeEvent) { item_kind = e.target.value; }
    async def handle_upload(e: ChangeEvent) {
        selected_file: any = e.target.files[0];
        if selected_file {
            if selected_file.size > 10485760 {
                uploaded_files = uploaded_files + [{"name": selected_file.name, "mime": selected_file.type or "Unknown", "size": selected_file.size, "course": course_choice, "content": "", "status": "Too large: maximum 10 MB"}];
            } elif selected_file.type == "text/plain" or selected_file.name.endswith(".txt") or selected_file.name.endswith(".csv") {
                text = await selected_file.text();
                uploaded_files = uploaded_files + [{"name": selected_file.name, "mime": selected_file.type or "text/plain", "size": selected_file.size, "course": course_choice, "content": text, "status": "Text ready; not sent yet"}];
            } elif selected_file.type == "application/pdf" or selected_file.name.endswith(".pdf") {
                try {
                    pdf_data = await selected_file.arrayBuffer();
                    pdf_task = getDocument({"data": pdf_data});
                    pdf_doc = await pdf_task.promise;
                    if pdf_doc.numPages > 60 {
                        uploaded_files = uploaded_files + [{"name": selected_file.name, "mime": "application/pdf", "size": selected_file.size, "course": course_choice, "content": "", "status": "Too many pages: maximum 60"}];
                    } else {
                        extracted: str = "";
                        for page_num in range(1, pdf_doc.numPages + 1) {
                            page = await pdf_doc.getPage(page_num);
                            page_text = await page.getTextContent();
                            for part in page_text.items { part_value: any = part; if part_value.str { extracted = extracted + str(part_value.str) + " "; } }
                            extracted = extracted + "\n";
                        }
                        await pdf_doc.destroy();
                        status = "PDF text ready; not sent yet" if extracted.strip() else "No PDF text found; scanned PDF cannot be OCRed here";
                        uploaded_files = uploaded_files + [{"name": selected_file.name, "mime": "application/pdf", "size": selected_file.size, "course": course_choice, "content": extracted, "status": status}];
                    }
                } except Exception { uploaded_files = uploaded_files + [{"name": selected_file.name, "mime": "application/pdf", "size": selected_file.size, "course": course_choice, "content": "", "status": "PDF extraction failed"}]; }
            } elif selected_file.type == "image/png" or selected_file.type == "image/jpeg" or selected_file.name.endswith(".png") or selected_file.name.endswith(".jpg") or selected_file.name.endswith(".jpeg") {
                try {
                    ocr_worker = await createWorker("eng");
                    ocr_result = await ocr_worker.recognize(selected_file);
                    await ocr_worker.terminate();
                    extracted_image = str(ocr_result.data.text);
                    status_image = "Image OCR ready; not sent yet" if extracted_image.strip() else "No readable text found in image";
                    uploaded_files = uploaded_files + [{"name": selected_file.name, "mime": selected_file.type or "image", "size": selected_file.size, "course": course_choice, "content": extracted_image, "status": status_image}];
                } except Exception { uploaded_files = uploaded_files + [{"name": selected_file.name, "mime": selected_file.type or "image", "size": selected_file.size, "course": course_choice, "content": "", "status": "Image OCR failed"}]; }
            } else {
                uploaded_files = uploaded_files + [{"name": selected_file.name, "mime": selected_file.type or "Unknown", "size": selected_file.size, "course": course_choice, "content": "", "status": "Unsupported format"}];
            }
        }
    }
    def remove_file(index: int) {
        remaining: list[dict] = [];
        for (i, record) in enumerate(uploaded_files) { if i != index { remaining = remaining + [record]; } }
        uploaded_files = remaining;
    }

    async def handle_login() {
        auth_message = "";
        try {
            ok: bool = False;
            ok = await jacLogin(email, password);
            if ok { await load_workspace(); }
            else { auth_message = "Sign-in failed. Check your email and password."; }
        } except Exception { auth_message = "Sign-in failed. Check your email and password."; }
    }

    async def handle_signup() {
        auth_message = "";
        try {
            signup_result: dict | None = None;
            login_ok: bool = False;
            signup_result = await jacSignup(email, password);
            if signup_result["success"] {
                login_ok = await jacLogin(email, password);
                if login_ok { await load_workspace(); }
                else { auth_message = "Account created. Sign in to continue."; }
            } else { auth_message = str(signup_result["error"] or "Could not create the account."); }
        } except Exception { auth_message = "Could not create account. Try another email and a longer password."; }
    }

    async def handle_save_setup() {
        page_error = "";
        try {
            ok: bool = False;
            ok = await save_academic_setup(university, faculty, department, batch, semester, timezone, int(weekly_hours_text), courses_text);
            if ok { await load_workspace(); }
            else { page_error = "Add a university, semester, 1–80 weekly hours, and valid courses in JSON format."; }
        } except Exception { page_error = "Could not save profile and courses. Check required values and try again."; }
    }

    async def handle_add_item() {
        page_error = "";
        try {
            starts_at = item_date + ("T" + item_time if item_time else "");
            is_date_only = not item_time;
            ok: bool = False;
            ok = await add_academic_item(item_kind, item_title, item_course, starts_at, "", is_date_only, item_venue, item_topic, "Study " + item_topic if item_topic else "Review course material", int(item_minutes_text), "normal");
            if ok {
                item_title = "";
                await load_workspace();
            } else { page_error = "Enter a title and valid duration, then try again."; }
        } except Exception { page_error = "Could not save the academic item."; }
    }

    async def handle_toggle_task(task_id: str, done: bool) {
        try {
            changed: bool = False;
            changed = await set_study_task_done(task_id, done);
            if changed { await load_workspace(); }
        } except Exception { page_error = "Could not update this task. Your earlier progress remains saved."; }
    }

    async def send_chat() {
        if chat_input.strip() and not chat_busy {
            chat_busy = True;
            chat_error = "";
            message = chat_input.strip();
            file_context = "";
            for file_record in uploaded_files {
                if file_record["content"] and str(file_record["status"]).endswith("not sent yet") {
                    file_context = file_context + "\n\n[Student-approved extracted text from " + str(file_record["name"]) + "]\n" + str(file_record["content"]);
                }
            }
            sent_message = message + file_context;
            next_history = chat_history + [{"role": "student", "text": message}];
            chat_history = next_history;
            chat_input = "";
            context_text = "";
            for turn in next_history { context_text = context_text + str(turn["role"]) + ": " + str(turn["text"]) + "\n"; }
            try {
                answer = await respond_with_gemini(sent_message, context_text);
                chat_history = chat_history + [{"role": "assistant", "text": answer}];
                updated_files: list[dict] = [];
                for file_record in uploaded_files {
                    if file_record["content"] and str(file_record["status"]).endswith("not sent yet") { updated_files = updated_files + [{**file_record, "status": "Text shared with Gemini for this message"}]; }
                    else { updated_files = updated_files + [file_record]; }
                }
                uploaded_files = updated_files;
            } except Exception { chat_error = "Gemini could not respond. Check GEMINI_API_KEY and retry; your selected files have not been marked as sent."; }
            chat_busy = False;
        }
    }

    if not jacIsLoggedIn() {
        return <div className="grid min-h-screen bg-muted/40 lg:grid-cols-2"><section className="hidden flex-col justify-between bg-primary p-12 text-primary-foreground lg:flex"><div className="flex items-center gap-3"><div className="rounded-lg bg-primary-foreground/15 p-2"><HugeiconsIcon icon={BookOpen01Icon} strokeWidth={2} className="size-5" /></div><div><p className="text-lg font-semibold">Daymark</p><p className="text-sm text-primary-foreground/75">University Academic Assistant</p></div></div><div className="max-w-lg"><h1 className="text-4xl font-semibold tracking-tight">A clearer path through the semester.</h1><p className="mt-4 text-primary-foreground/80">Plan courses, lectures, study sessions, and revision in a private academic workspace.</p></div><p className="text-sm text-primary-foreground/75">Your records stay scoped to your signed-in account.</p></section><main className="flex min-h-screen items-center justify-center p-6"><Card className="w-full max-w-md shadow-sm"><CardHeader><CardTitle>Sign in to your academic workspace</CardTitle><CardDescription>Create an account or sign in to access your private academic graph.</CardDescription></CardHeader><CardContent className="flex flex-col gap-3"><label htmlFor="email" className="text-sm font-medium">Email</label><Input id="email" type="email" value={email} onChange={handle_email} placeholder="you@university.edu" /><label htmlFor="password" className="text-sm font-medium">Password</label><Input id="password" type="password" value={password} onChange={handle_password} placeholder="At least 8 characters" /><p role="alert" className="text-sm text-destructive">{auth_message}</p><div className="flex gap-2"><Button className="flex-1" onClick={handle_login}>Sign in</Button><Button variant="outline" className="flex-1" onClick={handle_signup}>Create account</Button></div><p className="text-xs text-muted-foreground">Authentication is provided by Jac’s built-in account system. Use a unique password; never reuse your university portal password.</p></CardContent></Card></main></div>;
    }

    if loading {
        return <div className="flex min-h-screen items-center justify-center bg-muted/40"><Card className="p-8 text-sm text-muted-foreground">Loading your private academic workspace…</Card></div>;
    }

    configured = workspace is not None and workspace.configured;
    course_count = len(workspace.courses) if workspace is not None else 0;
    event_count = len(workspace.events) if workspace is not None else 0;
    task_count = len(workspace.tasks) if workspace is not None else 0;
    topic_count = len(workspace.topics) if workspace is not None else 0;
    completion = int((workspace.completed_count * 100) / workspace.planned_count) if workspace is not None and workspace.planned_count > 0 else 0;
    header_university = "Academic workspace";
    header_semester = "Setup";
    header_faculty = "Phase 1 · Academic workspace";
    if workspace is not None {
        header_university = workspace.university;
        header_semester = workspace.semester;
        header_faculty = workspace.faculty + " · " + workspace.department;
    }

    return <div className="min-h-screen bg-muted/40 text-foreground"><div className="mx-auto flex min-h-screen w-full max-w-[1600px]"><aside className="hidden w-60 shrink-0 flex-col border-r bg-card px-4 py-6 lg:flex"><div className="mb-9 flex items-center gap-3 px-2"><div className="flex size-9 items-center justify-center rounded-xl bg-primary text-primary-foreground"><HugeiconsIcon icon={BookOpen01Icon} strokeWidth={2} className="size-5" /></div><div><p className="font-semibold">Daymark</p><p className="text-xs text-muted-foreground">Academic workspace</p></div></div><p className="mb-2 px-3 text-xs font-medium text-muted-foreground">WORKSPACE</p><nav className="flex flex-col gap-1"><a href="#today" className="rounded-lg bg-primary/10 px-3 py-2 text-sm font-medium text-primary">Dashboard</a><a href="#calendar" className="rounded-lg px-3 py-2 text-sm text-muted-foreground hover:bg-muted">Calendar</a><a href="#study-plan" className="rounded-lg px-3 py-2 text-sm text-muted-foreground hover:bg-muted">Study plan</a><a href="#courses" className="rounded-lg px-3 py-2 text-sm text-muted-foreground hover:bg-muted">Courses & knowledge map</a></nav><div className="mt-auto rounded-xl border bg-muted/40 p-4"><p className="text-sm font-medium">Private workspace</p><p className="mt-1 text-xs leading-relaxed text-muted-foreground">Saved to your signed-in Jac graph. External integrations are not configured.</p></div></aside><main className="min-w-0 flex-1"><header className="sticky top-0 z-10 flex h-16 items-center justify-between border-b bg-background/95 px-4 backdrop-blur sm:px-7"><div className="flex items-center gap-3 lg:hidden"><div className="flex size-8 items-center justify-center rounded-lg bg-primary text-primary-foreground"><HugeiconsIcon icon={BookOpen01Icon} strokeWidth={2} className="size-4" /></div><span className="font-semibold">Daymark</span></div><div className="hidden text-sm text-muted-foreground lg:block">{header_university} · {header_semester}</div><div className="flex items-center gap-3"><span className="hidden text-sm text-muted-foreground sm:inline">{workspace.timezone if workspace is not None else "UTC"}</span><Button variant="outline" size="sm" onClick={lambda { jacLogout(); workspace = None; }}>Sign out</Button></div></header><div className="mx-auto flex w-full flex-col gap-5 p-4 sm:p-6 xl:p-8"><div id="today" className="flex flex-wrap items-end justify-between gap-3"><div><p className="text-sm text-muted-foreground">{header_faculty}</p><h1 className="mt-1 text-2xl font-semibold tracking-tight sm:text-3xl">{header_semester + " study dashboard" if configured else "Set up your academic workspace"}</h1><p className="mt-1 text-sm text-muted-foreground">Persistent courses, academic events, and study tasks. Planning is based on your saved records.</p></div><Badge variant="outline" className="bg-card">Private graph · signed in</Badge></div>
        {if page_error {<p role="alert" className="rounded-lg bg-destructive/10 p-3 text-sm text-destructive">{page_error}</p>}}
        {if not configured {<Card className="shadow-sm"><CardHeader><CardTitle>Student profile and courses</CardTitle><CardDescription>Set your term details and paste your course list as JSON. Example: CS1033, Programming Fundamentals, 3 credits, topics Variables and Functions.</CardDescription></CardHeader><CardContent className="grid gap-3 sm:grid-cols-2"><label className="text-sm">University<Input value={university} onChange={handle_university} placeholder="University name" /></label><label className="text-sm">Faculty<Input value={faculty} onChange={handle_faculty} placeholder="Faculty" /></label><label className="text-sm">Department<Input value={department} onChange={handle_department} placeholder="Department" /></label><label className="text-sm">Batch<Input value={batch} onChange={handle_batch} placeholder="2026 intake" /></label><label className="text-sm">Semester<Input value={semester} onChange={handle_semester} placeholder="Semester 1" /></label><label className="text-sm">Timezone<Input value={timezone} onChange={handle_timezone} placeholder="Asia/Colombo" /></label><label className="text-sm">Available study hours per week<Input type="number" value={weekly_hours_text} onChange={handle_hours} /></label><label className="text-sm sm:col-span-2">Courses as JSON<textarea value={courses_text} onChange={handle_courses} rows={5} className="mt-1 w-full rounded-md border border-input bg-background p-3 font-mono text-xs" placeholder="[]" /></label><div className="sm:col-span-2"><Button onClick={handle_save_setup}>Save profile and courses</Button></div></CardContent></Card>}}
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4"><Card><CardContent className="p-4"><p className="text-xs text-muted-foreground">Courses</p><p className="mt-1 text-2xl font-semibold tabular-nums">{str(course_count)}</p></CardContent></Card><Card><CardContent className="p-4"><p className="text-xs text-muted-foreground">Academic events</p><p className="mt-1 text-2xl font-semibold tabular-nums">{str(event_count)}</p></CardContent></Card><Card><CardContent className="p-4"><p className="text-xs text-muted-foreground">Study checklist</p><p className="mt-1 text-2xl font-semibold tabular-nums">{str(workspace.completed_count if workspace is not None else 0)}/{str(task_count)}</p></CardContent></Card><Card><CardContent className="p-4"><p className="text-xs text-muted-foreground">Study activity</p><p className="mt-1 text-2xl font-semibold tabular-nums">{str(workspace.completed_minutes if workspace is not None else 0)} min</p></CardContent></Card></div>
        <div className="grid gap-5 xl:grid-cols-[minmax(0,1fr)_350px]"><div className="flex min-w-0 flex-col gap-5"><Card id="calendar" className="shadow-sm"><CardHeader><CardTitle>Academic calendar and study plan</CardTitle><CardDescription>Events use your saved local date/time; no fabricated deadlines are shown.</CardDescription></CardHeader><CardContent className="grid gap-3 sm:grid-cols-2"><label className="text-sm">Title<Input value={item_title} onChange={handle_item_title} placeholder="Lecture, quiz, assignment or study task" /></label><label className="text-sm">Type<select value={item_kind} onChange={handle_kind} className="mt-1 h-10 w-full rounded-md border border-input bg-background px-3 text-sm"><option value="task">Study task</option><option value="lecture">Lecture</option><option value="quiz">Quiz</option><option value="exam">Exam</option><option value="assignment">Assignment</option><option value="holiday">Holiday</option><option value="event">Other event</option></select></label><label className="text-sm">Course code (optional)<Input value={item_course} onChange={handle_item_course} placeholder="CS1033" /></label><label className="text-sm">Date<Input type="date" value={item_date} onChange={handle_item_date} /></label><label className="text-sm">Start time (optional)<Input type="time" value={item_time} onChange={handle_item_time} /></label><label className="text-sm">Venue (optional)<Input value={item_venue} onChange={handle_item_venue} placeholder="Building and room" /></label><label className="text-sm">Topic (for study task)<Input value={item_topic} onChange={handle_item_topic} placeholder="Syllabus topic" /></label><label className="text-sm">Planned minutes<Input type="number" value={item_minutes_text} onChange={handle_item_minutes} /></label><div className="sm:col-span-2"><Button onClick={handle_add_item}><HugeiconsIcon icon={Add01Icon} strokeWidth={2} className="mr-2 size-4" />Add to my graph</Button></div></CardContent></Card>
        <Card id="study-plan" className="shadow-sm"><CardHeader><CardTitle>Upcoming events and study checklist</CardTitle><CardDescription>Completion is saved on your private academic graph and does not imply mastery or assignment submission.</CardDescription></CardHeader><CardContent className="flex flex-col gap-2">{if task_count == 0 and event_count == 0 {<p className="rounded-lg border border-dashed p-6 text-sm text-muted-foreground">No saved tasks or events yet. Add a lecture, deadline, or study task above.</p>}}{if workspace is not None {for (i, event) in enumerate(workspace.events) {<div key={"event" + str(i)} className="flex flex-wrap items-center justify-between gap-3 rounded-lg border p-3"><div><p className="font-medium">{event.title}</p><p className="text-xs text-muted-foreground">{event.kind} · {event.course_code} · {event.starts_at if event.starts_at else "Date not set"} · {event.venue if event.venue else "Venue not provided"}</p></div><Badge variant="outline">{"Confirmed" if event.verified else "Needs review"}</Badge></div>}}}{if workspace is not None {for task in workspace.tasks {<button key={task.id} onClick={lambda { handle_toggle_task(task.id, not task.done); }} className="flex items-start gap-3 rounded-lg border bg-card p-3 text-left hover:bg-muted/40"><span className={"mt-0.5 flex size-5 shrink-0 items-center justify-center rounded-full border " + ("border-primary bg-primary text-primary-foreground" if task.done else "border-border")}>{task.done and <HugeiconsIcon icon={CheckmarkCircle02Icon} strokeWidth={2} className="size-4" />}</span><span className="min-w-0 flex-1"><span className={"block text-sm font-medium " + ("text-muted-foreground line-through" if task.done else "")}>{task.title}</span><span className="mt-1 block text-xs text-muted-foreground">{task.course_code} · {task.topic} · {task.action} · {str(task.minutes)} min</span></span><Badge variant="outline">{"Completed" if task.done else "Not started"}</Badge></button>}}}</CardContent></Card>
        <div className="grid gap-5 lg:grid-cols-2"><Card id="courses" className="shadow-sm"><CardHeader><CardTitle>Forward knowledge graph</CardTitle><CardDescription>Directed course-to-topic links from your saved data.</CardDescription></CardHeader><CardContent className="flex flex-col gap-2">{if topic_count == 0 {<p className="rounded-lg border border-dashed p-5 text-sm text-muted-foreground">No syllabus topics yet. Add topics in the course setup JSON to create directed graph nodes.</p>}}{if workspace is not None {for topic in workspace.topics {<div key={topic.course_code + topic.title} className="grid grid-cols-[100px_24px_minmax(0,1fr)] items-center gap-2 text-xs"><span className="rounded-md border bg-primary/5 p-2 font-semibold">{topic.course_code}</span><span className="text-center text-primary">→</span><span className="rounded-md border bg-card p-2">{topic.title} <span className="text-muted-foreground">· {topic.source}</span></span></div>}}}</CardContent></Card><Card className="shadow-sm"><CardHeader><CardTitle>Study report</CardTitle><CardDescription>Saved checklist activity, not a mastery estimate.</CardDescription></CardHeader><CardContent className="flex flex-col gap-3"><div className="flex items-center justify-between text-sm"><span>Checklist completion</span><span>{str(completion)}%</span></div><Progress value={completion} /><p className="text-sm">{str(workspace.completed_count if workspace is not None else 0)} of {str(task_count)} tasks completed.</p><p className="text-xs text-muted-foreground">Study minutes record activity only; recall evidence and syllabus coverage are not yet included in readiness.</p></CardContent></Card></div>
        </div><aside className="flex min-w-0 flex-col gap-4" aria-label="Academic assistant"><Card className="flex flex-col shadow-sm xl:sticky xl:top-20"><CardHeader className="border-b"><div className="flex items-center gap-3"><div className="flex size-9 items-center justify-center rounded-lg bg-primary/10 text-primary"><HugeiconsIcon icon={SparklesIcon} strokeWidth={2} className="size-5" /></div><div><CardTitle>Academic assistant</CardTitle><CardDescription>Chat and attach study materials</CardDescription></div></div></CardHeader><CardContent className="flex flex-col gap-3 p-4"><div className="max-h-56 min-h-28 overflow-y-auto rounded-xl border bg-muted/30 p-3">{if len(chat_history) == 0 {<p className="rounded-lg bg-card p-3 text-sm">Ask about your saved courses, lectures, or study tasks. Uploaded text is sent only when you press Send.</p>}}{for (i, turn) in enumerate(chat_history) {<p key={str(i)} className={"mb-2 rounded-lg p-3 text-sm " + ("ml-5 bg-primary text-primary-foreground" if turn["role"] == "student" else "mr-5 bg-card")}>{turn["text"]}</p>}}</div><label htmlFor="chat-course" className="text-xs font-medium">Attach to course</label><select id="chat-course" value={course_choice} onChange={handle_course_choice} className="h-9 rounded-md border border-input bg-background px-3 text-sm"><option value="">No course selected</option>{if workspace is not None {for course in workspace.courses {<option key={course.code} value={course.code}>{course.code} · {course.title}</option>}}}</select><label htmlFor="chat-file" className="text-xs font-medium">Add PDF, image, TXT, or CSV note</label><input id="chat-file" type="file" accept=".pdf,.txt,.csv,.png,.jpg,.jpeg" onChange={handle_upload} className="block w-full rounded-md border border-input bg-background px-2 py-2 text-xs file:mr-2 file:rounded file:border-0 file:bg-primary file:px-3 file:py-1 file:text-primary-foreground" /><p className="text-xs text-muted-foreground">Files up to 10 MB are extracted locally. PDF limit 60 pages. Image OCR uses English and may be imperfect. Files remain on this device.</p>{for (i, record) in enumerate(uploaded_files) {<div key={str(i)} className="flex items-center justify-between gap-2 rounded-md border bg-muted/30 p-2"><span className="break-all text-xs">{record["name"]} · {record["status"]}</span><button type="button" onClick={lambda { remove_file(i); }} className="rounded border px-2 py-1 text-xs">Remove</button></div>}}<label htmlFor="chat-message" className="sr-only">Message</label><Input id="chat-message" value={chat_input} onChange={handle_chat_input} placeholder="Ask about your courses or attached notes" /><div className="flex items-center justify-between gap-2"><span className="text-xs text-muted-foreground">Chat is not saved.</span><Button size="sm" disabled={chat_busy} onClick={send_chat}>{"Thinking…" if chat_busy else "Send"}</Button></div>{if chat_error {<p role="alert" className="text-sm text-destructive">{chat_error}</p>}}</CardContent></Card><Card className="shadow-sm"><CardHeader><CardTitle>Connections</CardTitle><CardDescription>Not configured in this workspace</CardDescription></CardHeader><CardContent className="flex flex-col gap-2 text-sm"><p>Drive: Not connected</p><p>Email / WhatsApp: Not connected</p><p>Campus routes: Unavailable</p><p>University submission: Not connected</p></CardContent></Card></aside></div><footer className="border-t pt-4 text-xs text-muted-foreground">Phase 1 workspace · Graph data persists per signed-in account. Provider integrations remain disconnected.</footer></div></main></div></div>;
}
