import from "@jac/runtime" { Link }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { DashboardSquare01Icon, Calendar03Icon, Task01Icon, Analytics01Icon, Settings01Icon, Notification01Icon, Clock01Icon, Location01Icon, SparklesIcon, Add01Icon, CheckmarkCircle02Icon, BookOpen01Icon }
import from .ui.card { Card, CardHeader, CardTitle, CardDescription, CardContent }
import from .ui.button { Button }
import from .ui.badge { Badge }
import from .ui.progress { Progress }
import from .ui.input { Input }
import from "pdfjs-dist" { getDocument }
sv import from ..services.chatService { respond_to_chat }

# A practical daily plan with transparent demo data and local-only interactions.
def:pub StudyPlanner() -> JsxElement {
    has task_text: str = "";
    has tasks: list[dict] = [
        {"title": "Review lecture 04: memory and cognition", "course": "PSY 204 · Cognitive Psychology", "duration": "45 min", "done": False},
        {"title": "Complete problem set, questions 1–6", "course": "MATH 221 · Linear Algebra", "duration": "60 min", "done": False},
        {"title": "Recall check: eigenvalues and eigenvectors", "course": "MATH 221 · Linear Algebra", "duration": "15 min", "done": True}
    ];
    has assistant_note: str = "I can help review lecture notes, venue text, and timetable candidates shared in chat.";
    has uploaded_files: list[dict] = [];
    has course_choice: str = "CS1033";
    has chat_input: str = "";
    has chat_history: list[dict] = [];
    has chat_busy: bool = False;
    has chat_error: str = "";
    def handle_course_choice(e: ChangeEvent) { course_choice = e.target.value; }
    def handle_chat_input(e: ChangeEvent) { chat_input = e.target.value; }
    async def handle_upload(e: ChangeEvent) {
        selected_file: any = e.target.files[0];
        if selected_file {
            if selected_file.size > 10485760 {
                uploaded_files = uploaded_files + [{"name": selected_file.name, "mime": selected_file.type or "Unknown file type", "size": selected_file.size, "course": course_choice, "content": "", "status": "Too large: choose a file under 10 MB"}];
            } elif selected_file.type == "text/plain" or selected_file.name.endswith(".txt") or selected_file.name.endswith(".csv") {
                content = await selected_file.text();
                uploaded_files = uploaded_files + [{"name": selected_file.name, "mime": selected_file.type or "text/plain", "size": selected_file.size, "course": course_choice, "content": content, "status": "Text ready; not sent yet"}];
            } elif selected_file.type == "application/pdf" or selected_file.name.endswith(".pdf") {
                try {
                    pdf_data = await selected_file.arrayBuffer();
                    pdf_task = getDocument({"data": pdf_data});
                    pdf_doc = await pdf_task.promise;
                    if pdf_doc.numPages > 60 {
                        uploaded_files = uploaded_files + [{"name": selected_file.name, "mime": "application/pdf", "size": selected_file.size, "course": course_choice, "content": "", "status": "Too many pages: limit is 60 pages"}];
                    } else {
                        extracted_text = "";
                        for page_num in range(1, pdf_doc.numPages + 1) {
                            page = await pdf_doc.getPage(page_num);
                            text_content = await page.getTextContent();
                            for item in text_content.items { item_value: any = item; if item_value.str { extracted_text = extracted_text + str(item_value.str) + " "; } }
                            extracted_text = extracted_text + "\n";
                        }
                        if extracted_text.strip() {
                            uploaded_files = uploaded_files + [{"name": selected_file.name, "mime": "application/pdf", "size": selected_file.size, "course": course_choice, "content": extracted_text, "status": "PDF text ready; not sent yet"}];
                        } else {
                            uploaded_files = uploaded_files + [{"name": selected_file.name, "mime": "application/pdf", "size": selected_file.size, "course": course_choice, "content": "", "status": "No selectable text found; scanned PDFs need OCR"}];
                        }
                        await pdf_doc.destroy();
                    }
                } except Exception {
                    uploaded_files = uploaded_files + [{"name": selected_file.name, "mime": "application/pdf", "size": selected_file.size, "course": course_choice, "content": "", "status": "Could not read PDF text; try a text/CSV file"}];
                }
            } else {
                uploaded_files = uploaded_files + [{"name": selected_file.name, "mime": selected_file.type or "Unknown file type", "size": selected_file.size, "course": course_choice, "content": "", "status": "Unsupported here: use PDF, TXT, or CSV"}];
            }
        }
    }
    def remove_file(index: int) {
        remaining: list[dict] = [];
        for (i, record) in enumerate(uploaded_files) { if i != index { remaining = remaining + [record]; } }
        uploaded_files = remaining;
    }
    async def send_chat() {
        if chat_input.strip() and not chat_busy {
            chat_busy = True;
            chat_error = "";
            message = chat_input.strip();
            file_context = "";
            for file_record in uploaded_files {
                if file_record["content"] and str(file_record["status"]).endswith("not sent yet") {
                    file_context = file_context + "\n\n[Student-selected text file: " + str(file_record["name"]) + "]\n" + str(file_record["content"]);
                }
            }
            sent_message = message + file_context;
            updated_history = chat_history + [{"role": "student", "text": message}];
            chat_history = updated_history;
            chat_input = "";
            context_text = "";
            for turn in updated_history { context_text = context_text + str(turn["role"]) + ": " + str(turn["text"]) + "\n"; }
            try {
                answer = await respond_to_chat(sent_message, context_text);
                chat_history = chat_history + [{"role": "assistant", "text": answer}];
                updated_files: list[dict] = [];
                for file_record in uploaded_files {
                    if str(file_record["status"]).endswith("not sent yet") and file_record["content"] { updated_files = updated_files + [{**file_record, "status": "Text shared with assistant for this request"}]; }
                    else { updated_files = updated_files + [file_record]; }
                }
                uploaded_files = updated_files;
                assistant_note = answer;
            } except Exception {
                chat_error = "The assistant could not respond. Check the AI provider configuration in Settings and try again.";
            }
            chat_busy = False;
        }
    }
    done_count = len([task for task in tasks if task["done"]]);
    pct = int((done_count * 100) / len(tasks)) if len(tasks) > 0 else 0;
    def handle_text(e: ChangeEvent) { task_text = e.target.value; }
    def handle_add(e: MouseEvent) {
        if task_text.strip() {
            tasks = tasks + [{"title": task_text.strip(), "course": "Personal study task", "duration": "30 min", "done": False}];
            task_text = "";
        }
    }
    def toggle_task(index: int) {
        next_tasks: list[dict] = [];
        for (i, task) in enumerate(tasks) {
            if i == index { next_tasks = next_tasks + [{**task, "done": not task["done"]}]; }
            else { next_tasks = next_tasks + [task]; }
        }
        tasks = next_tasks;
    }
    def handle_assistant(e: ChangeEvent) { assistant_note = e.target.value; }

    return <div className="min-h-screen bg-muted/40 text-foreground">
        <div className="mx-auto flex min-h-screen w-full max-w-[1600px]">
            <aside className="hidden w-60 shrink-0 flex-col border-r bg-card px-4 py-6 lg:flex">
                <div className="mb-9 flex items-center gap-3 px-2">
                    <div className="flex size-9 items-center justify-center rounded-xl bg-primary text-primary-foreground"><HugeiconsIcon icon={BookOpen01Icon} strokeWidth={2} className="size-5" /></div>
                    <div><p className="font-semibold tracking-tight">Daymark</p><p className="text-xs text-muted-foreground">Your study companion</p></div>
                </div>
                <p className="mb-2 px-3 text-xs font-medium text-muted-foreground">WORKSPACE</p>
                <nav className="flex flex-col gap-1">
                    <a href="#today" className="flex items-center gap-3 rounded-lg bg-primary/10 px-3 py-2.5 text-sm font-medium text-primary"><HugeiconsIcon icon={DashboardSquare01Icon} strokeWidth={2} className="size-4" />Dashboard</a>
                    <a href="#timetable" className="flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm text-muted-foreground hover:bg-muted"><HugeiconsIcon icon={Calendar03Icon} strokeWidth={2} className="size-4" />Calendar</a>
                    <a href="#today" className="flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm text-muted-foreground hover:bg-muted"><HugeiconsIcon icon={Task01Icon} strokeWidth={2} className="size-4" />Study plan</a>
                    <a href="#courses" className="flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm text-muted-foreground hover:bg-muted"><HugeiconsIcon icon={BookOpen01Icon} strokeWidth={2} className="size-4" />Courses & notes</a>
                    <a href="#progress" className="flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm text-muted-foreground hover:bg-muted"><HugeiconsIcon icon={Analytics01Icon} strokeWidth={2} className="size-4" />Reports</a>
                </nav>
                <div className="mt-auto rounded-xl border bg-muted/40 p-4"><p className="text-sm font-medium">Keep it realistic</p><p className="mt-1 text-xs leading-relaxed text-muted-foreground">Your plan leaves room for breaks and unexpected work.</p></div>
            </aside>
            <main className="min-w-0 flex-1">
                <header className="sticky top-0 z-10 flex h-16 items-center justify-between border-b bg-background/95 px-4 backdrop-blur sm:px-7">
                    <div className="flex items-center gap-3 lg:hidden"><div className="flex size-8 items-center justify-center rounded-lg bg-primary text-primary-foreground"><HugeiconsIcon icon={BookOpen01Icon} strokeWidth={2} className="size-4" /></div><span className="font-semibold">Daymark</span></div>
                    <div className="hidden text-sm text-muted-foreground lg:block">Fall semester <span className="px-1">/</span> Week 6</div>
                    <div className="flex items-center gap-3"><span className="hidden text-sm text-muted-foreground sm:inline">Thursday, October 22</span><Button variant="ghost" size="icon" aria-label="Notifications"><HugeiconsIcon icon={Notification01Icon} strokeWidth={2} className="size-4" /></Button><div className="flex size-8 items-center justify-center rounded-full bg-muted text-xs font-semibold">AN</div></div>
                </header>
                <div className="mx-auto flex w-full flex-col gap-5 p-4 sm:p-6 xl:p-8">
                    <div className="flex flex-wrap items-end justify-between gap-3" id="today"><div><p className="text-sm text-muted-foreground">Thursday, October 22 · Fall semester</p><h1 className="mt-1 text-2xl font-semibold tracking-tight sm:text-3xl">A steady day, one session at a time.</h1><p className="mt-1 text-sm text-muted-foreground">Your study plan is a starting point. Adjust it whenever you need.</p></div><Badge variant="outline" className="gap-1.5 bg-card"><span className="size-2 rounded-full bg-emerald-500"></span>Saved on this device</Badge></div>
                    <div className="grid grid-cols-1 gap-5 xl:grid-cols-[minmax(0,1fr)_320px]">
                        <div className="flex min-w-0 flex-col gap-5">
                            <div className="grid gap-4 md:grid-cols-2">
                                <Card className="overflow-hidden border-primary/20 bg-primary text-primary-foreground shadow-sm">
                                    <CardContent className="flex min-h-44 flex-col justify-between p-5"><div className="flex items-start justify-between"><div><p className="text-sm text-primary-foreground/75">NEXT UP · LECTURE</p><h2 className="mt-2 text-xl font-semibold">Cognitive Psychology</h2><p className="mt-1 text-sm text-primary-foreground/80">PSY 204 · Lecture 08</p></div><div className="rounded-lg bg-primary-foreground/15 p-2"><HugeiconsIcon icon={BookOpen01Icon} strokeWidth={2} className="size-5" /></div></div><div className="flex flex-wrap items-center gap-x-5 gap-y-2 border-t border-primary-foreground/20 pt-3 text-sm"><span className="flex items-center gap-1.5"><HugeiconsIcon icon={Clock01Icon} strokeWidth={2} className="size-4" />10:30–11:45</span><span className="flex items-center gap-1.5"><HugeiconsIcon icon={Location01Icon} strokeWidth={2} className="size-4" />Science Hall · Room 214</span></div></CardContent>
                                </Card>
                                <Card className="shadow-sm"><CardContent className="flex h-full min-h-44 flex-col justify-between p-5"><div><p className="text-sm font-medium text-muted-foreground">NEXT DEADLINE</p><h2 className="mt-2 text-xl font-semibold">Statistics problem set</h2><p className="mt-1 text-sm text-muted-foreground">STAT 210 · Due Friday, October 24</p></div><div className="mt-4 flex items-end justify-between"><div><p className="text-3xl font-semibold tabular-nums">1 day</p><p className="text-xs text-muted-foreground">Date only; no deadline time provided</p></div><Badge variant="secondary">In progress</Badge></div></CardContent></Card>
                            </div>
                            <div className="grid gap-5 lg:grid-cols-[minmax(0,1.25fr)_minmax(280px,0.75fr)]">
                                <Card className="shadow-sm"><CardHeader className="flex flex-row items-start justify-between gap-4 pb-3"><div><CardTitle>Today’s study plan</CardTitle><CardDescription className="mt-1">A focused plan with space to breathe</CardDescription></div><span className="text-sm font-medium tabular-nums">{str(done_count)}/{str(len(tasks))} done</span></CardHeader><CardContent className="flex flex-col gap-4"><div className="flex items-center gap-3"><Progress value={pct} className="h-2 flex-1" /><span className="text-xs tabular-nums text-muted-foreground">{str(pct)}%</span></div><div className="flex flex-col divide-y">{for (i, task) in enumerate(tasks) {<button key={str(i)} onClick={lambda { toggle_task(i); }} className="group flex items-start gap-3 py-3 text-left"><span className={"mt-0.5 flex size-5 shrink-0 items-center justify-center rounded-full border " + ("border-primary bg-primary text-primary-foreground" if task["done"] else "border-border bg-background")}>{task["done"] and <HugeiconsIcon icon={CheckmarkCircle02Icon} strokeWidth={2} className="size-4" />}</span><span className="min-w-0 flex-1"><span className={"block text-sm font-medium " + ("text-muted-foreground line-through" if task["done"] else "")}>{task["title"]}</span><span className="mt-1 block text-xs text-muted-foreground">{task["course"]}</span></span><span className="whitespace-nowrap text-xs text-muted-foreground">{task["duration"]}</span></button>}}</div><div className="flex gap-2"><Input aria-label="New study task" placeholder="Add a study task" value={task_text} onChange={handle_text} onKeyDown={lambda (e: KeyboardEvent) { if e.key == "Enter" { tasks = tasks + [{"title": task_text.strip(), "course": "Personal study task", "duration": "30 min", "done": False}]; task_text = ""; } }} /><Button aria-label="Add study task" size="icon" onClick={handle_add}><HugeiconsIcon icon={Add01Icon} strokeWidth={2} className="size-4" /></Button></div></CardContent></Card>
                                <Card id="timetable" className="shadow-sm"><CardHeader className="pb-3"><CardTitle>Today’s timetable</CardTitle><CardDescription>Local times · venue as provided</CardDescription></CardHeader><CardContent className="flex flex-col gap-0"><div className="flex gap-3 border-l-2 border-primary py-3 pl-4"><div className="w-12 shrink-0 text-xs font-medium tabular-nums">10:30</div><div><p className="text-sm font-medium">Cognitive Psychology</p><p className="mt-1 text-xs text-muted-foreground">Science Hall · Room 214</p><Badge className="mt-2" variant="secondary">Next lecture</Badge></div></div><div className="flex gap-3 border-l-2 border-border py-3 pl-4"><div className="w-12 shrink-0 text-xs font-medium tabular-nums">13:00</div><div><p className="text-sm font-medium">Linear Algebra</p><p className="mt-1 text-xs text-muted-foreground">Mathematics Building · Room 108</p></div></div><div className="flex gap-3 border-l-2 border-border py-3 pl-4"><div className="w-12 shrink-0 text-xs font-medium tabular-nums">15:00</div><div><p className="text-sm font-medium">Independent study</p><p className="mt-1 text-xs text-muted-foreground">Library · Quiet study floor</p></div></div><div className="mt-3 rounded-lg bg-muted/60 p-3"><p className="text-xs font-medium">Route guidance unavailable</p><p className="mt-1 text-xs leading-relaxed text-muted-foreground">Venue details are shown as entered. No campus map or travel-time service is connected.</p></div></CardContent></Card>
                            </div>
                            <div className="grid gap-5 md:grid-cols-2" id="progress">
                                <Card className="shadow-sm"><CardHeader className="pb-3"><CardTitle>Study activity this week</CardTitle><CardDescription>Student-reported study time · demo data</CardDescription></CardHeader><CardContent><div className="flex items-end justify-between gap-2 border-b pb-4" aria-label="Weekly study activity chart; Monday 40, Tuesday 65, Wednesday 35, Thursday 55, Friday 20 minutes"><div className="flex flex-1 flex-col items-center gap-2"><div className="w-full rounded-t bg-primary/40" style={{"height":"36px"}}></div><span className="text-xs text-muted-foreground">Mon</span></div><div className="flex flex-1 flex-col items-center gap-2"><div className="w-full rounded-t bg-primary/65" style={{"height":"58px"}}></div><span className="text-xs text-muted-foreground">Tue</span></div><div className="flex flex-1 flex-col items-center gap-2"><div className="w-full rounded-t bg-primary/45" style={{"height":"32px"}}></div><span className="text-xs text-muted-foreground">Wed</span></div><div className="flex flex-1 flex-col items-center gap-2"><div className="w-full rounded-t bg-primary" style={{"height":"50px"}}></div><span className="text-xs text-muted-foreground">Thu</span></div><div className="flex flex-1 flex-col items-center gap-2"><div className="w-full rounded-t bg-primary/25" style={{"height":"18px"}}></div><span className="text-xs text-muted-foreground">Fri</span></div></div><p className="pt-3 text-xs text-muted-foreground">Planned and completed minutes are not yet connected. Time spent alone is not proof of mastery.</p></CardContent></Card>
                                <Card id="courses" className="shadow-sm"><CardHeader className="pb-3"><CardTitle>Courses from your image</CardTitle><CardDescription>Course credits transcribed from the supplied course list · 14 credits total</CardDescription></CardHeader><CardContent className="flex flex-col gap-2"><div className="grid grid-cols-[minmax(0,1fr)_auto] gap-x-3 border-b pb-2 text-xs font-medium text-muted-foreground"><span>COURSE</span><span>CREDITS</span></div><div className="flex items-center justify-between gap-3 py-1.5"><span className="text-sm"><span className="font-semibold">CS1033</span> · Programming Fundamentals</span><span className="tabular-nums text-sm">3</span></div><div className="flex items-center justify-between gap-3 py-1.5"><span className="text-sm"><span className="font-semibold">EE1040</span> · Electrical Fundamentals</span><span className="tabular-nums text-sm">2</span></div><div className="flex items-center justify-between gap-3 py-1.5"><span className="text-sm"><span className="font-semibold">MA1014</span> · Mathematics</span><span className="tabular-nums text-sm">3</span></div><div className="flex items-center justify-between gap-3 py-1.5"><span className="text-sm"><span className="font-semibold">ME1033</span> · Mechanics</span><span className="tabular-nums text-sm">2</span></div><div className="flex items-center justify-between gap-3 py-1.5"><span className="text-sm"><span className="font-semibold">CE1023</span> · Fluid Mechanics</span><span className="tabular-nums text-sm">2</span></div><div className="flex items-center justify-between gap-3 py-1.5"><span className="text-sm"><span className="font-semibold">MT1023</span> · Properties of Materials</span><span className="tabular-nums text-sm">2</span></div><p className="border-t pt-3 text-xs text-muted-foreground">Credits are transcribed from your image; course activation and study-hour allocation are not yet saved.</p><div className="mt-2 rounded-xl border bg-muted/30 p-3"><p className="text-xs font-semibold">Directed course source graph</p><p className="mb-3 mt-1 text-xs text-muted-foreground">Arrows mean “listed in source,” not verified timetable assignments.</p><div className="grid grid-cols-[minmax(84px,0.7fr)_24px_minmax(0,1.6fr)] items-center gap-x-2 gap-y-2 text-xs"><div className="row-span-6 flex min-h-28 items-center justify-center rounded-lg border border-primary/30 bg-primary/10 p-2 text-center font-medium text-primary">Course list<br/>image</div><span className="text-center text-primary">→</span><div className="rounded-md border bg-card px-2 py-1.5"><strong>CS1033</strong> · Programming Fundamentals · 3 cr</div><span className="text-center text-primary">→</span><div className="rounded-md border bg-card px-2 py-1.5"><strong>EE1040</strong> · Electrical Fundamentals · 2 cr</div><span className="text-center text-primary">→</span><div className="rounded-md border bg-card px-2 py-1.5"><strong>MA1014</strong> · Mathematics · 3 cr</div><span className="text-center text-primary">→</span><div className="rounded-md border bg-card px-2 py-1.5"><strong>ME1033</strong> · Mechanics · 2 cr</div><span className="text-center text-primary">→</span><div className="rounded-md border bg-card px-2 py-1.5"><strong>CE1023</strong> · Fluid Mechanics · 2 cr</div><span className="text-center text-primary">→</span><div className="rounded-md border bg-card px-2 py-1.5"><strong>MT1023</strong> · Properties of Materials · 2 cr</div></div>{if len(uploaded_files) > 0 {<div className="mt-3 rounded-xl border bg-card p-3"><p className="text-xs font-semibold">Chat-shared file nodes → course links</p>{for (i, record) in enumerate(uploaded_files) {<div key={str(i)} className="mt-2 grid grid-cols-[minmax(0,1fr)_20px_minmax(0,0.8fr)_auto] items-center gap-2 rounded-lg border bg-muted/30 p-2"><div className="min-w-0 rounded-md border bg-card p-2"><p className="break-all text-xs font-medium">{record["name"]}</p><p className="mt-1 text-xs text-muted-foreground">{record["mime"]} · {str(round((record["size"] as int) / 1024))} KB</p><p className="text-xs text-muted-foreground">{record["status"]}</p></div><span className="text-center text-primary">→</span><div className="rounded-md border border-primary/30 bg-primary/5 p-2 text-xs"><p className="font-semibold">{record["course"]}</p><p className="text-muted-foreground">Pending review</p></div><button type="button" aria-label="Remove selected file" onClick={lambda { remove_file(i); }} className="rounded-md border px-2 py-1 text-xs hover:bg-muted">Remove</button></div>}}</div>}}<div className="mt-3 rounded-lg border border-dashed bg-card p-2.5"><p className="text-xs font-medium">Timetable image · Semester I 2025</p><p className="mt-1 text-xs text-muted-foreground">Legacy source, not a current saved schedule. These visible rows are candidate links only; confirm each before planning.</p><Badge className="mt-2" variant="outline">Unverified · review required</Badge><div className="mt-3 flex flex-col gap-2 border-t pt-3"><p className="text-xs font-medium">Candidate course → timetable links</p><div className="grid grid-cols-[minmax(0,0.8fr)_20px_minmax(0,1fr)] items-center gap-2 text-xs"><span className="rounded border border-dashed px-2 py-1.5"><strong>MA1014</strong><br/>Mathematics</span><span className="text-center text-primary">→</span><span className="rounded border border-dashed bg-muted/40 px-2 py-1.5">Tue · 10:15–11:15<br/>Room text unclear</span><span className="rounded border border-dashed px-2 py-1.5"><strong>CS1033</strong><br/>Programming Fundamentals</span><span className="text-center text-primary">→</span><span className="rounded border border-dashed bg-muted/40 px-2 py-1.5">Fri · 10:15–11:15<br/>Lab · room unclear</span><span className="rounded border border-dashed px-2 py-1.5"><strong>MT1023</strong><br/>Properties of Materials</span><span className="text-center text-primary">→</span><span className="rounded border border-dashed bg-muted/40 px-2 py-1.5">Mon · 13:15–14:15<br/>Venue needs review</span><span className="rounded border border-dashed px-2 py-1.5"><strong>CE1023</strong><br/>Fluid Mechanics</span><span className="text-center text-primary">→</span><span className="rounded border border-dashed bg-muted/40 px-2 py-1.5">Tue · 13:15–14:15<br/>Venue needs review</span><span className="rounded border border-dashed px-2 py-1.5"><strong>CS1033</strong><br/>Programming Fundamentals</span><span className="text-center text-primary">→</span><span className="rounded border border-dashed bg-muted/40 px-2 py-1.5">Wed · 13:15–14:15<br/>Venue needs review</span><span className="rounded border border-dashed px-2 py-1.5"><strong>MA1014</strong><br/>Mathematics</span><span className="text-center text-primary">→</span><span className="rounded border border-dashed bg-muted/40 px-2 py-1.5">Thu · 13:15–14:15<br/>Venue needs review</span><span className="rounded border border-dashed px-2 py-1.5"><strong>ME1033</strong><br/>Mechanics</span><span className="text-center text-primary">→</span><span className="rounded border border-dashed bg-muted/40 px-2 py-1.5">Fri · 13:15–14:15<br/>Venue needs review</span></div><p className="text-xs leading-relaxed text-muted-foreground">Times and course labels are read from a rotated, small timetable image and may be misread. This list is not imported into the dashboard timetable and should not be treated as a verified schedule.</p></div></div></div></CardContent></Card>
                            </div>
                        </div>
                        <aside className="flex min-w-0 flex-col gap-5" aria-label="Academic assistant">
                            <Card className="flex flex-col shadow-sm xl:sticky xl:top-20"><CardHeader className="border-b pb-4"><div className="flex items-center gap-3"><div className="flex size-9 items-center justify-center rounded-lg bg-primary/10 text-primary"><HugeiconsIcon icon={SparklesIcon} strokeWidth={2} className="size-5" /></div><div><CardTitle>Academic assistant</CardTitle><CardDescription className="mt-1">Chat, attach notes, review together</CardDescription></div></div></CardHeader><CardContent className="flex flex-col gap-3 p-4"><p className="text-xs leading-relaxed text-muted-foreground">Gemini replies need GEMINI_API_KEY in JacHammer Settings; restart the preview after adding it. Text file contents are sent only when you press Send. Other file formats aren’t extracted in this demo.</p><div className="flex max-h-72 min-h-32 flex-col gap-3 overflow-y-auto rounded-xl border bg-muted/30 p-3" aria-live="polite">{if len(chat_history) == 0 {<div className="rounded-lg bg-card p-3 text-sm leading-relaxed"><p className="text-xs font-medium">Daymark assistant</p><p className="mt-1">Ask about a course, share lecture notes, or paste venue details. I’ll identify timetable candidates for you to review before treating them as confirmed.</p></div>}}{for (i, turn) in enumerate(chat_history) {<div key={str(i)} className={"max-w-[92%] rounded-lg p-3 text-sm leading-relaxed " + ("self-end bg-primary text-primary-foreground" if turn["role"] == "student" else "self-start bg-card")}>{turn["text"]}</div>}}</div><div className="flex flex-col gap-2 rounded-lg border bg-card p-3"><label htmlFor="chat-file-course" className="text-xs font-medium">Associate attached file with</label><select id="chat-file-course" value={course_choice} onChange={handle_course_choice} className="h-9 rounded-md border border-input bg-background px-3 text-sm"><option value="CS1033">CS1033 · Programming Fundamentals</option><option value="EE1040">EE1040 · Electrical Fundamentals</option><option value="MA1014">MA1014 · Mathematics</option><option value="ME1033">ME1033 · Mechanics</option><option value="CE1023">CE1023 · Fluid Mechanics</option><option value="MT1023">MT1023 · Properties of Materials</option></select><label htmlFor="chat-file" className="text-xs font-medium">Attach lecture notes or venue details</label><input id="chat-file" type="file" accept=".pdf,.txt,.csv" onChange={handle_upload} className="block w-full cursor-pointer rounded-md border border-input bg-background px-2 py-2 text-xs text-muted-foreground file:mr-3 file:rounded file:border-0 file:bg-primary file:px-3 file:py-1 file:text-xs file:font-medium file:text-primary-foreground" /><p className="text-xs text-muted-foreground">PDF, TXT, and CSV up to 10 MB are read locally in this browser; PDF extraction is limited to 60 pages. Scanned PDFs need OCR and DOCX/Office files aren’t supported. Extracted text stays a draft until you send; no file is uploaded to server storage.</p>{for (i, file_record) in enumerate(uploaded_files) {<div key={str(i)} className="flex items-center justify-between gap-2 rounded-md border bg-muted/40 px-2 py-1.5"><span className="min-w-0 break-all text-xs">{file_record["name"]} · {file_record["status"]}</span><button type="button" onClick={lambda { remove_file(i); }} className="shrink-0 rounded border px-2 py-1 text-xs hover:bg-muted">Remove</button></div>}}</div>{if chat_error {<p role="alert" className="rounded-lg bg-destructive/10 p-3 text-sm text-destructive">{chat_error}</p>}}<label className="sr-only" htmlFor="assistant-question">Message the academic assistant</label><Input id="assistant-question" placeholder="Ask about your courses or notes" value={chat_input} onChange={handle_chat_input} onKeyDown={lambda (e: KeyboardEvent) { if e.key == "Enter" { send_chat(); } }} /><div className="flex items-center justify-between gap-2"><span className="text-xs text-muted-foreground">No chat history is saved by this demo.</span><Button size="sm" disabled={chat_busy} onClick={send_chat}>{"Sending…" if chat_busy else "Send message"}</Button></div></CardContent></Card>
                            <Card className="shadow-sm"><CardHeader className="pb-3"><CardTitle>Connections</CardTitle><CardDescription>External services are optional</CardDescription></CardHeader><CardContent className="flex flex-col gap-3"><div className="flex items-center justify-between"><span className="text-sm">Drive</span><Badge variant="outline">Not connected</Badge></div><div className="flex items-center justify-between"><span className="text-sm">Email reminders</span><Badge variant="outline">Not connected</Badge></div><div className="flex items-center justify-between"><span className="text-sm">WhatsApp</span><Badge variant="outline">Not connected</Badge></div><p className="text-xs leading-relaxed text-muted-foreground">No files synced or reminders sent. Provider setup and student consent are required.</p></CardContent></Card>
                        </aside>
                    </div>
                    <footer className="flex flex-wrap items-center justify-between gap-2 border-t pt-4 text-xs text-muted-foreground"><span>Demo workspace · Changes stay in this browser session.</span><span>Campus routes and integrations are not configured.</span></footer>
                </div>
            </main>
        </div>
    </div>;
}
