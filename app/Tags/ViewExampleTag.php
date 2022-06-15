<?php

namespace App\Tags;

use Statamic\Tags\Tags;
use Statamic\View\View;

class ViewExampleTag extends Tags
{
    public function example()
    {
        echo View::make('example')->render();
    }
}
